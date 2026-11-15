import Foundation

public enum GarmentCategory: String, Codable, CaseIterable, Sendable {
    case top, pants
}

public struct SizeRange: Codable, Hashable, Sendable {
    public var min: Double
    public var max: Double

    public init(min: Double, max: Double) {
        self.min = min
        self.max = max
    }
}

/// The brand's body-size chart row for one size: the intended wearer, in centimetres.
public struct BodyChart: Codable, Hashable, Sendable {
    public var chest: SizeRange?
    public var waist: SizeRange?
    public var hips: SizeRange?
    public var inseam: SizeRange?

    public init(chest: SizeRange? = nil, waist: SizeRange? = nil, hips: SizeRange? = nil, inseam: SizeRange? = nil) {
        self.chest = chest
        self.waist = waist
        self.hips = hips
        self.inseam = inseam
    }
}

/// Actual product dimensions for one size, as full circumferences or lengths in centimetres.
public struct GarmentDimensions: Codable, Hashable, Sendable {
    public var chest: Double?
    public var waist: Double?
    public var hips: Double?
    public var inseam: Double?
    public var sleeve: Double?
    public var length: Double?

    public init(chest: Double? = nil, waist: Double? = nil, hips: Double? = nil, inseam: Double? = nil, sleeve: Double? = nil, length: Double? = nil) {
        self.chest = chest
        self.waist = waist
        self.hips = hips
        self.inseam = inseam
        self.sleeve = sleeve
        self.length = length
    }
}

public struct ProductVariant: Codable, Hashable, Identifiable, Sendable {
    public var id: String
    /// Display label such as "M" or "32 / Regular".
    public var sizeLabel: String
    public var inStock: Bool
    public var bodyChart: BodyChart?
    public var garment: GarmentDimensions?

    public init(id: String, sizeLabel: String, inStock: Bool = true, bodyChart: BodyChart? = nil, garment: GarmentDimensions? = nil) {
        self.id = id
        self.sizeLabel = sizeLabel
        self.inStock = inStock
        self.bodyChart = bodyChart
        self.garment = garment
    }
}

public struct Product: Codable, Hashable, Identifiable, Sendable {
    public var id: String
    public var brand: String
    public var name: String
    public var category: GarmentCategory
    public var collection: ShoppingCollection
    public var colorName: String
    public var priceCents: Int
    public var tagline: String
    public var details: [String]
    /// Retailer or demo photo. Shown under "Product photos" and when no 3D preview exists.
    public var imageURL: URL?
    public var sourceURL: URL?
    /// Name of the bundled dressed-model USDZ. nil means "Preview unavailable": show the photo instead.
    public var previewAsset: String?
    public var hasStretch: Bool
    /// True when every name, price, and measurement is invented for the demo.
    public var isFictional: Bool
    public var variants: [ProductVariant]

    public init(
        id: String, brand: String, name: String, category: GarmentCategory, collection: ShoppingCollection,
        colorName: String, priceCents: Int, tagline: String, details: [String] = [], imageURL: URL? = nil,
        sourceURL: URL? = nil, previewAsset: String? = nil, hasStretch: Bool = false, isFictional: Bool = true,
        variants: [ProductVariant]
    ) {
        self.id = id
        self.brand = brand
        self.name = name
        self.category = category
        self.collection = collection
        self.colorName = colorName
        self.priceCents = priceCents
        self.tagline = tagline
        self.details = details
        self.imageURL = imageURL
        self.sourceURL = sourceURL
        self.previewAsset = previewAsset
        self.hasStretch = hasStretch
        self.isFictional = isFictional
        self.variants = variants
    }

    public func variant(_ id: String) -> ProductVariant? {
        variants.first { $0.id == id }
    }
}
