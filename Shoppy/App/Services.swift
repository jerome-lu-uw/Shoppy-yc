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
    case declined
    case connection
}

/// Places a simulated order. No implementation may take a real payment.
protocol CheckoutService: Sendable {
    func placeDemoOrder(lines: [OrderLine], totalCents: Int) async throws -> DemoOrder
}

struct LocalDemoCheckout: CheckoutService {
    func placeDemoOrder(lines: [OrderLine], totalCents: Int) async throws -> DemoOrder {
        try await Task.sleep(for: .seconds(1.2))
        return DemoOrder(number: String(format: "SH-%05d", Int.random(in: 100...99_999)), lines: lines, totalCents: totalCents)
    }
}
