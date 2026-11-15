@testable import ShoppyCore

enum SizingFixtures {
    static let garmentTop = Product(
        id: "fixture-garment-top",
        brand: "Fixture",
        name: "Garment Top",
        category: .top,
        collection: .all,
        colorName: "Blue",
        priceCents: 6_800,
        tagline: "",
        variants: [
            ProductVariant(id: "fixture-garment-top-s", sizeLabel: "S", garment: GarmentDimensions(chest: 100, sleeve: 62, length: 68)),
            ProductVariant(id: "fixture-garment-top-m", sizeLabel: "M", garment: GarmentDimensions(chest: 108, sleeve: 64, length: 70)),
            ProductVariant(id: "fixture-garment-top-l", sizeLabel: "L", garment: GarmentDimensions(chest: 116, sleeve: 66, length: 72)),
        ]
    )

    static let bodyChartPants = Product(
        id: "fixture-body-chart-pants",
        brand: "Fixture",
        name: "Body Chart Pants",
        category: .pants,
        collection: .all,
        colorName: "Grey",
        priceCents: 9_200,
        tagline: "",
        variants: [
            ProductVariant(id: "fixture-body-chart-pants-30r", sizeLabel: "30 / Regular", bodyChart: BodyChart(waist: SizeRange(min: 74, max: 79))),
            ProductVariant(id: "fixture-body-chart-pants-32r", sizeLabel: "32 / Regular", bodyChart: BodyChart(waist: SizeRange(min: 79, max: 84))),
            ProductVariant(id: "fixture-body-chart-pants-34r", sizeLabel: "34 / Regular", bodyChart: BodyChart(waist: SizeRange(min: 84, max: 89))),
        ]
    )

    static let missingMeasurementsTop = Product(
        id: "fixture-missing-measurements-top",
        brand: "Fixture",
        name: "Missing Measurements Top",
        category: .top,
        collection: .all,
        colorName: "Green",
        priceCents: 8_600,
        tagline: "",
        variants: [
            ProductVariant(id: "fixture-missing-measurements-top-s", sizeLabel: "S"),
            ProductVariant(id: "fixture-missing-measurements-top-m", sizeLabel: "M"),
            ProductVariant(id: "fixture-missing-measurements-top-l", sizeLabel: "L"),
        ]
    )

    static let soldOutTop = Product(
        id: "fixture-sold-out-top",
        brand: "Fixture",
        name: "Sold-Out Top",
        category: .top,
        collection: .men,
        colorName: "Green",
        priceCents: 7_400,
        tagline: "",
        variants: [
            ProductVariant(id: "fixture-sold-out-top-s", sizeLabel: "S", garment: GarmentDimensions(chest: 102, sleeve: 63, length: 69)),
            ProductVariant(id: "fixture-sold-out-top-m", sizeLabel: "M", inStock: false, garment: GarmentDimensions(chest: 110, sleeve: 65, length: 71)),
            ProductVariant(id: "fixture-sold-out-top-l", sizeLabel: "L", garment: GarmentDimensions(chest: 118, sleeve: 67, length: 73)),
        ]
    )

    static let multiMeasurementPants = Product(
        id: "fixture-multi-measurement-pants",
        brand: "Fixture",
        name: "Multi-Measurement Pants",
        category: .pants,
        collection: .women,
        colorName: "Brown",
        priceCents: 10_800,
        tagline: "",
        hasStretch: true,
        variants: [
            ProductVariant(id: "fixture-multi-measurement-pants-s", sizeLabel: "S", garment: GarmentDimensions(waist: 78, hips: 100, inseam: 76)),
            ProductVariant(id: "fixture-multi-measurement-pants-m", sizeLabel: "M", garment: GarmentDimensions(waist: 84, hips: 106, inseam: 77)),
            ProductVariant(id: "fixture-multi-measurement-pants-l", sizeLabel: "L", garment: GarmentDimensions(waist: 90, hips: 112, inseam: 78)),
        ]
    )

    static let products = [garmentTop, bodyChartPants, missingMeasurementsTop, soldOutTop, multiMeasurementPants]
}
