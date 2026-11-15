import Foundation
import Testing
@testable import ShoppyCore

@Test func legacyDemoOrderDecodesAsDemo() throws {
    struct LegacyOrder: Codable {
        var id = "legacy-order"
        var number = "SH-00128"
        var lines: [OrderLine] = []
        var totalCents = 7_500
        var status = OrderStatus.confirmed
        var createdAt = Date(timeIntervalSinceReferenceDate: 100)
    }

    let data = try JSONEncoder().encode(LegacyOrder())
    let order = try JSONDecoder().decode(Order.self, from: data)

    #expect(order.environment == .demo)
    #expect(order.currency == "usd")
    #expect(order.clearedCartItemIDs.isEmpty)
    #expect(order.status == .confirmed)
}

@Test func onlyPendingPaymentIsNonterminal() {
    #expect(!OrderStatus.pendingPayment.isPaymentTerminal)
    for status in OrderStatus.allCases where status != .pendingPayment {
        #expect(status.isPaymentTerminal)
    }
}
