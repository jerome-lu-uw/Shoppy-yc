import ConvexMobile
import Foundation
import ShoppyCore

/// Calls the `orders:placeDemo` mutation. The server prices the order from the catalog and takes no payment.
/// A retry of the same bag reuses its idempotency key, so a dropped connection can never create two orders.
final class ConvexCheckout: CheckoutService, @unchecked Sendable {
    private let client: ConvexClient
    private let ownerId: String
    private let lock = NSLock()
    private var pending: (signature: String, key: String)?

    init(client: ConvexClient, ownerId: String) {
        self.client = client
        self.ownerId = ownerId
    }

    convenience init(sync: ConvexSync) {
        self.init(client: sync.client, ownerId: sync.ownerId)
    }

    func placeDemoOrder(lines: [OrderLine], totalCents: Int) async throws -> DemoOrder {
        let signature = lines.map { "\($0.productID)|\($0.variantID)|\($0.quantity)" }.joined(separator: ",")
        let key = idempotencyKey(for: signature)
        let wireLines: [ConvexEncodable?] = lines.map { line in
            let entry: [String: ConvexEncodable?] = [
                "productID": line.productID,
                "variantID": line.variantID,
                "quantity": Double(line.quantity),
            ]
            return entry
        }
        do {
            let order: WireOrder = try await client.mutation("orders:placeDemo", with: [
                "ownerId": ownerId,
                "idempotencyKey": key,
                "lines": wireLines,
            ])
            lock.withLock { pending = nil }
            return order.model
        } catch {
            backendLog.error("orders:placeDemo failed: \(String(describing: error))")
            throw CheckoutError.connection
        }
    }

    private func idempotencyKey(for signature: String) -> String {
        lock.withLock {
            if let pending, pending.signature == signature { return pending.key }
            let key = UUID().uuidString
            pending = (signature, key)
            return key
        }
    }
}
