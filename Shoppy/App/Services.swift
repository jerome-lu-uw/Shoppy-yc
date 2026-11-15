import Foundation
import ShoppyCore

/// Mirrors local changes to a backend. The store works without one.
@MainActor
protocol RemoteSync: AnyObject {
    /// Called once at launch: load remote state into the store and keep the catalog current.
    func start(store: AppStore)
    func setSaved(productID: String, saved: Bool)
    func upsertCartItem(_ item: CartItem)
    func removeCartItem(id: String)
    func saveProfile(_ profile: BodyProfile)
}

enum CheckoutError: Error {
    case unavailable
    case connection
    case invalidResponse
}

struct CheckoutSession: Sendable {
    var order: Order
    var checkoutURL: URL?
}

/// Starts a hosted sandbox checkout and waits for its signed webhook result.
protocol CheckoutService: Sendable {
    func startCheckout(items: [CartItem], lines: [OrderLine]) async throws -> CheckoutSession
    func waitForTerminalOrder(id: String) async throws -> Order
}

struct UnavailableCheckout: CheckoutService {
    func startCheckout(items: [CartItem], lines: [OrderLine]) async throws -> CheckoutSession {
        throw CheckoutError.unavailable
    }

    func waitForTerminalOrder(id: String) async throws -> Order {
        throw CheckoutError.unavailable
    }
}

#if DEBUG
actor PreviewCheckout: CheckoutService {
    private let fails: Bool
    private var orders: [String: Order] = [:]

    init(fails: Bool = false) {
        self.fails = fails
    }

    func startCheckout(items: [CartItem], lines: [OrderLine]) async throws -> CheckoutSession {
        let total = lines.reduce(0) { $0 + $1.unitPriceCents * $1.quantity }
        let order = Order(
            number: String(format: "SH-%05d", Int.random(in: 100...99_999)),
            lines: lines,
            totalCents: total,
            status: .pendingPayment,
            clearedCartItemIDs: items.map(\.id)
        )
        orders[order.id] = order
        return CheckoutSession(order: order, checkoutURL: nil)
    }

    func waitForTerminalOrder(id: String) async throws -> Order {
        try await Task.sleep(for: .seconds(1.2))
        guard var order = orders[id] else { throw CheckoutError.invalidResponse }
        order.status = fails ? .paymentFailed : .paid
        order.failureMessage = fails ? "The preview payment was declined." : nil
        order.paidAt = fails ? nil : .now
        orders[id] = order
        return order
    }
}
#endif
