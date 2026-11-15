import Foundation

public enum FitConfidence: String, Codable, Sendable {
    /// Enough evidence to select the size automatically.
    case confident
    /// Missing body or garment data: the user must confirm a size before checkout.
    case limited
}

public enum ComparisonBasis: String, Codable, Sendable {
    /// Body measurement against the garment's actual dimension.
    case garmentDimension
    /// Body measurement against the brand's body-size chart range.
    case bodyChart
}

public struct FitComparison: Codable, Hashable, Sendable {
    public var kind: MeasurementKind
    public var basis: ComparisonBasis
    public var bodyValue: Double
    public var bodySource: MeasurementSource
    /// Garment dimension, or the midpoint of the body-chart range.
    public var referenceValue: Double
    /// referenceValue minus bodyValue, in centimetres.
    public var ease: Double
    /// One plain sentence, for example "10 cm of room around the chest."
    public var note: String

    public init(kind: MeasurementKind, basis: ComparisonBasis, bodyValue: Double, bodySource: MeasurementSource, referenceValue: Double, ease: Double, note: String) {
        self.kind = kind
        self.basis = basis
        self.bodyValue = bodyValue
        self.bodySource = bodySource
        self.referenceValue = referenceValue
        self.ease = ease
        self.note = note
    }
}

public struct SizeRecommendation: Codable, Hashable, Sendable {
    /// nil when no in-stock variant can be suggested at all.
    public var variantID: String?
    public var confidence: FitConfidence
    /// Short title, for example "A little room to move."
    public var headline: String
    /// One line, for example "Room through the chest; regular sleeve length."
    public var summary: String
    public var comparisons: [FitComparison]
    /// Measurements that would raise confidence if the user supplied them.
    public var missing: [MeasurementKind]
    public var profileVersion: Int
    public var rulesVersion: String

    public init(variantID: String?, confidence: FitConfidence, headline: String, summary: String, comparisons: [FitComparison] = [], missing: [MeasurementKind] = [], profileVersion: Int, rulesVersion: String = ShoppyCore.rulesVersion) {
        self.variantID = variantID
        self.confidence = confidence
        self.headline = headline
        self.summary = summary
        self.comparisons = comparisons
        self.missing = missing
        self.profileVersion = profileVersion
        self.rulesVersion = rulesVersion
    }
}

public enum SizingEngine {
    /// Placeholder until the rule-based engine lands: suggests the middle in-stock size with limited confidence.
    public static func recommend(product: Product, profile: BodyProfile) -> SizeRecommendation {
        let inStock = product.variants.filter(\.inStock)
        return SizeRecommendation(
            variantID: inStock.isEmpty ? nil : inStock[inStock.count / 2].id,
            confidence: .limited,
            headline: "Review your size.",
            summary: "Add measurements for a better suggestion.",
            missing: [.chest, .waist, .inseam],
            profileVersion: profile.version
        )
    }
}
