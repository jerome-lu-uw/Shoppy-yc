import Foundation

public enum SizeSource: String, Codable, Sendable {
    case suggested, userChosen
}

public struct CartItem: Codable, Hashable, Identifiable, Sendable {
    public var id: String
    public var productID: String
    public var variantID: String
    public var quantity: Int
    public var sizeSource: SizeSource
    /// Set when measurements change after the item was added; checkout stays blocked until reviewed.
    public var needsSizeReview: Bool
    public var profileVersion: Int

    public init(id: String = UUID().uuidString, productID: String, variantID: String, quantity: Int = 1, sizeSource: SizeSource, needsSizeReview: Bool = false, profileVersion: Int) {
        self.id = id
        self.productID = productID
        self.variantID = variantID
        self.quantity = quantity
        self.sizeSource = sizeSource
        self.needsSizeReview = needsSizeReview
        self.profileVersion = profileVersion
    }
}

public struct OrderLine: Codable, Hashable, Sendable {
    public var productID: String
    public var variantID: String
    public var title: String
    public var sizeLabel: String
    public var quantity: Int
    public var unitPriceCents: Int

    public init(productID: String, variantID: String, title: String, sizeLabel: String, quantity: Int, unitPriceCents: Int) {
        self.productID = productID
        self.variantID = variantID
        self.title = title
        self.sizeLabel = sizeLabel
        self.quantity = quantity
        self.unitPriceCents = unitPriceCents
    }
}

public enum OrderStatus: String, Codable, CaseIterable, Sendable {
    case confirmed, preparing, shipped
    case pendingPayment, paid, paymentFailed, refunded

    public var isPaymentTerminal: Bool {
        self != .pendingPayment
    }
}

public enum CheckoutEnvironment: String, Codable, Sendable {
    case demo, sandbox
}

/// An order priced by Shoppy and optionally paid through the Whop sandbox.
public struct Order: Codable, Hashable, Identifiable, Sendable {
    public var id: String
    public var number: String
    public var lines: [OrderLine]
    public var totalCents: Int
    public var currency: String
    public var status: OrderStatus
    public var environment: CheckoutEnvironment
    public var clearedCartItemIDs: [String]
    public var failureMessage: String?
    public var createdAt: Date
    public var paidAt: Date?

    public init(
        id: String = UUID().uuidString,
        number: String,
        lines: [OrderLine],
        totalCents: Int,
        currency: String = "usd",
        status: OrderStatus = .pendingPayment,
        environment: CheckoutEnvironment = .sandbox,
        clearedCartItemIDs: [String] = [],
        failureMessage: String? = nil,
        createdAt: Date = .now,
        paidAt: Date? = nil
    ) {
        self.id = id
        self.number = number
        self.lines = lines
        self.totalCents = totalCents
        self.currency = currency
        self.status = status
        self.environment = environment
        self.clearedCartItemIDs = clearedCartItemIDs
        self.failureMessage = failureMessage
        self.createdAt = createdAt
        self.paidAt = paidAt
    }

    private enum CodingKeys: String, CodingKey {
        case id, number, lines, totalCents, currency, status, environment
        case clearedCartItemIDs, failureMessage, createdAt, paidAt
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(String.self, forKey: .id)
        number = try values.decode(String.self, forKey: .number)
        lines = try values.decode([OrderLine].self, forKey: .lines)
        totalCents = try values.decode(Int.self, forKey: .totalCents)
        currency = try values.decodeIfPresent(String.self, forKey: .currency) ?? "usd"
        status = try values.decode(OrderStatus.self, forKey: .status)
        environment = try values.decodeIfPresent(CheckoutEnvironment.self, forKey: .environment) ?? .demo
        clearedCartItemIDs = try values.decodeIfPresent([String].self, forKey: .clearedCartItemIDs) ?? []
        failureMessage = try values.decodeIfPresent(String.self, forKey: .failureMessage)
        createdAt = try values.decode(Date.self, forKey: .createdAt)
        paidAt = try values.decodeIfPresent(Date.self, forKey: .paidAt)
    }
}
