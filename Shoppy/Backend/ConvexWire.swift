import ConvexMobile
import Foundation
import ShoppyCore

/// A Convex number: a plain JSON number, or the tagged form the client uses for special values.
struct WireNumber: Decodable {
    let value: Double

    init(from decoder: Decoder) throws {
        if let double = try? decoder.singleValueContainer().decode(Double.self) {
            value = double
            return
        }
        value = try ConvexFloat<Double>(from: decoder).wrappedValue
    }
}

struct WireRange: Decodable {
    var min: WireNumber
    var max: WireNumber
    var model: SizeRange { SizeRange(min: min.value, max: max.value) }
}

struct WireVariant: Decodable {
    struct Chart: Decodable {
        var chest, waist, hips, inseam: WireRange?
    }

    struct Garment: Decodable {
        var chest, waist, hips, inseam, sleeve, length: WireNumber?
    }

    var id: String
    var sizeLabel: String
    var inStock: Bool
    var bodyChart: Chart?
    var garment: Garment?

    var model: ProductVariant {
        ProductVariant(
            id: id, sizeLabel: sizeLabel, inStock: inStock,
            bodyChart: bodyChart.map { BodyChart(chest: $0.chest?.model, waist: $0.waist?.model, hips: $0.hips?.model, inseam: $0.inseam?.model) },
            garment: garment.map { GarmentDimensions(chest: $0.chest?.value, waist: $0.waist?.value, hips: $0.hips?.value, inseam: $0.inseam?.value, sleeve: $0.sleeve?.value, length: $0.length?.value) }
        )
    }
}

struct WireProduct: Decodable {
    var productId: String
    var brand: String
    var name: String
    var category: GarmentCategory
    var collection: ShoppingCollection
    var colorName: String
    var priceCents: WireNumber
    var tagline: String
    var details: [String]
    var imageURL: String?
    var sourceURL: String?
    var previewAsset: String?
    var hasStretch: Bool
    var isFictional: Bool
    var variants: [WireVariant]

    var model: Product {
        Product(
            id: productId, brand: brand, name: name, category: category, collection: collection, colorName: colorName,
            priceCents: Int(priceCents.value), tagline: tagline, details: details,
            imageURL: imageURL.flatMap(URL.init(string:)), sourceURL: sourceURL.flatMap(URL.init(string:)),
            previewAsset: previewAsset, hasStretch: hasStretch, isFictional: isFictional, variants: variants.map(\.model)
        )
    }
}

struct WireProfile: Decodable {
    struct Entry: Decodable {
        var value: WireNumber
        var source: MeasurementSource
        var updatedAt: WireNumber
    }

    var name: String
    var measurements: [String: Entry]
    var fitPreference: FitPreference
    var collection: ShoppingCollection
    var units: UnitSystem
    var version: WireNumber

    var model: BodyProfile {
        var profile = BodyProfile(name: name, fitPreference: fitPreference, collection: collection, units: units, version: Int(version.value))
        for (key, entry) in measurements {
            guard let kind = MeasurementKind(rawValue: key) else { continue }
            profile.measurements[kind] = .init(value: entry.value.value, source: entry.source, updatedAt: Date(timeIntervalSince1970: entry.updatedAt.value / 1000))
        }
        return profile
    }
}

struct WireLike: Decodable {
    var productId: String
}

struct WireCartItem: Decodable {
    var itemId: String
    var productID: String
    var variantID: String
    var quantity: WireNumber
    var sizeSource: SizeSource
    var needsSizeReview: Bool
    var profileVersion: WireNumber

    var model: CartItem {
        CartItem(id: itemId, productID: productID, variantID: variantID, quantity: Int(quantity.value), sizeSource: sizeSource, needsSizeReview: needsSizeReview, profileVersion: Int(profileVersion.value))
    }
}

struct WireOrder: Decodable {
    struct Line: Decodable {
        var productID: String
        var variantID: String
        var title: String
        var sizeLabel: String
        var quantity: WireNumber
        var unitPriceCents: WireNumber
    }

    var _id: String
    var number: String
    var lines: [Line]
    var totalCents: WireNumber
    var currency: String?
    var status: OrderStatus
    var environment: CheckoutEnvironment?
    var clearedCartItemIDs: [String]?
    var failureMessage: String?
    var createdAt: WireNumber
    var paidAt: WireNumber?

    var model: Order {
        Order(
            id: _id, number: number,
            lines: lines.map { OrderLine(productID: $0.productID, variantID: $0.variantID, title: $0.title, sizeLabel: $0.sizeLabel, quantity: Int($0.quantity.value), unitPriceCents: Int($0.unitPriceCents.value)) },
            totalCents: Int(totalCents.value),
            currency: currency ?? "usd",
            status: status,
            environment: environment ?? .demo,
            clearedCartItemIDs: clearedCartItemIDs ?? [],
            failureMessage: failureMessage,
            createdAt: Date(timeIntervalSince1970: createdAt.value / 1000),
            paidAt: paidAt.map { Date(timeIntervalSince1970: $0.value / 1000) }
        )
    }
}

struct WireCheckoutSession: Decodable {
    var order: WireOrder
    var checkoutURL: String
}
