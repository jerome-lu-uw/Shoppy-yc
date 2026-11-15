import ConvexMobile
import CryptoKit
import Foundation
import ShoppyCore

/// Creates a Whop sandbox checkout through Convex and trusts only the resulting webhook-backed order status.
final class ConvexCheckout: CheckoutService, @unchecked Sendable {
    private let client: ConvexClient
    private let ownerId: String

    init(client: ConvexClient, ownerId: String) {
        self.client = client
        self.ownerId = ownerId
    }

    convenience init(sync: ConvexSync) {
        self.init(client: sync.client, ownerId: sync.ownerId)
    }

    func startCheckout(items: [CartItem], lines: [OrderLine]) async throws -> CheckoutSession {
        let wireItems: [ConvexEncodable?] = items.map { item in
            let entry: [String: ConvexEncodable?] = [
                "itemId": item.id,
                "productID": item.productID,
                "variantID": item.variantID,
                "quantity": Double(item.quantity),
            ]
            return entry
        }
        do {
            let session: WireCheckoutSession = try await client.action("checkout:start", with: [
                "ownerId": ownerId,
                "idempotencyKey": idempotencyKey(for: items),
                "items": wireItems,
            ])
            guard
                let url = URL(string: session.checkoutURL),
                url.scheme == "https",
                url.host == "sandbox.whop.com"
            else {
                throw CheckoutError.invalidResponse
            }
            return CheckoutSession(order: session.order.model, checkoutURL: url)
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as CheckoutError {
            throw error
        } catch {
            backendLog.error("checkout:start failed: \(String(describing: error))")
            throw CheckoutError.connection
        }
    }

    func waitForTerminalOrder(id: String) async throws -> Order {
        do {
            for try await wireOrder in client.subscribe(
                to: "orders:get",
                with: ["ownerId": ownerId, "orderId": id],
                yielding: WireOrder?.self
            ).values {
                try Task.checkCancellation()
                guard let order = wireOrder?.model else { throw CheckoutError.invalidResponse }
                if order.status.isPaymentTerminal {
                    return order
                }
            }
            throw CheckoutError.connection
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as CheckoutError {
            throw error
        } catch {
            backendLog.error("orders:get subscription failed: \(String(describing: error))")
            throw CheckoutError.connection
        }
    }

    private func idempotencyKey(for items: [CartItem]) -> String {
        let signature = items
            .sorted { $0.id < $1.id }
            .map { "\($0.id)|\($0.productID)|\($0.variantID)|\($0.quantity)" }
            .joined(separator: ",")
        let digest = SHA256.hash(data: Data(signature.utf8))
        return "shoppy_" + digest.map { String(format: "%02x", $0) }.joined()
    }
}
