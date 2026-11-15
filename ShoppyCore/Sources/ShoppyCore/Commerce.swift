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

public enum DemoOrderStatus: String, Codable, CaseIterable, Sendable {
    case confirmed, preparing, shipped
}

/// A simulated order. No payment is taken and nothing ships.
public struct DemoOrder: Codable, Hashable, Identifiable, Sendable {
    public var id: String
    /// Display number such as "SH-00128".
    public var number: String
    public var lines: [OrderLine]
    public var totalCents: Int
    public var status: DemoOrderStatus
    public var createdAt: Date

    public init(id: String = UUID().uuidString, number: String, lines: [OrderLine], totalCents: Int, status: DemoOrderStatus = .confirmed, createdAt: Date = .now) {
        self.id = id
        self.number = number
        self.lines = lines
        self.totalCents = totalCents
        self.status = status
        self.createdAt = createdAt
    }
}
