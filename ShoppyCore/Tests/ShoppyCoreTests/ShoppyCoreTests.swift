import Foundation
import Testing
@testable import ShoppyCore

private func profile(chest: Double? = nil, waist: Double? = nil, hips: Double? = nil, inseam: Double? = nil, sleeve: Double? = nil, fit: FitPreference = .regular) -> BodyProfile {
    var body = BodyProfile(fitPreference: fit, version: 7)
    body.measurements[.height] = .init(value: 178)
    body.measurements[.weight] = .init(value: 75)
    for (kind, value) in [(MeasurementKind.chest, chest), (.waist, waist), (.hips, hips), (.inseam, inseam), (.sleeve, sleeve)] {
        if let value { body.measurements[kind] = .init(value: value) }
    }
    return body
}

private let garmentTop = SizingFixtures.garmentTop
private let bodyChartPants = SizingFixtures.bodyChartPants

private func label(_ product: Product, _ rec: SizeRecommendation) -> String? {
    rec.variantID.flatMap { product.variant($0)?.sizeLabel }
}

@Test func catalogIDsAreUniqueAndSourcesAreExplicit() {
    let ids = SeedCatalog.products.map(\.id)
    #expect(Set(ids).count == ids.count)
    let variantIDs = SeedCatalog.products.flatMap(\.variants).map(\.id)
    #expect(Set(variantIDs).count == variantIDs.count)
    #expect(SeedCatalog.products.count == 4)
    #expect(SeedCatalog.products.allSatisfy { !$0.isFictional })
    #expect(SeedCatalog.products.allSatisfy { $0.sourceURL != nil })
    #expect(SeedCatalog.products.allSatisfy { $0.previewAsset?.hasPrefix("look-") == true })
    #expect(SeedCatalog.products.allSatisfy { $0.priceCents % 100 == 0 })
}

@Test func garmentMeasurementsAnchor() {
    let rec = SizingEngine.recommend(product: garmentTop, profile: profile(chest: 98))
    #expect(label(garmentTop, rec) == "M")
    #expect(rec.confidence == .confident)
    #expect(rec.comparisons.first { $0.kind == .chest }?.note == "10 cm of room around the chest.")
    #expect(rec.profileVersion == 7)
    #expect(rec.rulesVersion == ShoppyCore.rulesVersion)
}

@Test func bodyChartAnchor() {
    let rec = SizingEngine.recommend(product: bodyChartPants, profile: profile(chest: 98, waist: 82))
    #expect(label(bodyChartPants, rec) == "32 / Regular")
    #expect(rec.confidence == .confident)
}

@Test func fitPreferenceShiftsPick() {
    #expect(label(garmentTop, SizingEngine.recommend(product: garmentTop, profile: profile(chest: 98, fit: .close))) == "M")
    let closeSmall = SizingEngine.recommend(product: garmentTop, profile: profile(chest: 96, fit: .close))
    let regularSmall = SizingEngine.recommend(product: garmentTop, profile: profile(chest: 96, fit: .regular))
    #expect(label(garmentTop, closeSmall) == "S")
    #expect(label(garmentTop, regularSmall) == "M")
    let relaxed = SizingEngine.recommend(product: garmentTop, profile: profile(chest: 100, fit: .relaxed))
    let regular = SizingEngine.recommend(product: garmentTop, profile: profile(chest: 100, fit: .regular))
    #expect(label(garmentTop, relaxed) == "L")
    #expect(label(garmentTop, regular) == "M")
    let chartRelaxed = SizingEngine.recommend(product: bodyChartPants, profile: profile(waist: 82, fit: .relaxed))
    #expect(label(bodyChartPants, chartRelaxed) == "34 / Regular")
}

@Test func stretchToleratesLessEase() {
    var stretch = garmentTop
    let body = profile(chest: 98)
    stretch.hasStretch = true
    stretch.variants[1].garment?.chest = 104
    let rec = SizingEngine.recommend(product: stretch, profile: body)
    #expect(label(stretch, rec) == "M")
    stretch.variants[2].garment?.chest = 105
    let rec2 = SizingEngine.recommend(product: stretch, profile: body)
    #expect(label(stretch, rec2) == "L")
}

@Test func missingBodyMeasurementIsLimited() {
    let rec = SizingEngine.recommend(product: garmentTop, profile: profile())
    #expect(rec.confidence == .limited)
    #expect(label(garmentTop, rec) == "M")
    #expect(rec.missing.contains(.chest))
    #expect(rec.summary.contains("chest"))
    let heightOnly = SizingEngine.recommend(product: bodyChartPants, profile: profile())
    #expect(heightOnly.confidence == .limited)
    #expect(heightOnly.missing.contains(.waist))
}

@Test func missingProductDataIsLimited() {
    let product = SizingFixtures.missingMeasurementsTop
    let rec = SizingEngine.recommend(product: product, profile: profile(chest: 98, waist: 82))
    #expect(rec.confidence == .limited)
    #expect(label(product, rec) == "M")
    #expect(rec.comparisons.isEmpty)
    #expect(rec.missing.isEmpty)
    #expect(rec.summary.contains("detailed measurements"))
}

@Test func outOfStockIsNeverSuggested() {
    let product = SizingFixtures.soldOutTop
    let rec = SizingEngine.recommend(product: product, profile: profile(chest: 98))
    #expect(label(product, rec) == "S")
    #expect(rec.confidence == .confident)
    #expect(rec.summary.contains("M is out of stock"))
}

@Test func noInStockVariantsGivesNilID() {
    var soldOut = garmentTop
    soldOut.variants = soldOut.variants.map { var v = $0; v.inStock = false; return v }
    let rec = SizingEngine.recommend(product: soldOut, profile: profile(chest: 98))
    #expect(rec.variantID == nil)
    #expect(rec.confidence == .limited)
}

@Test func bodyChartBoundaries() {
    func pick(_ waist: Double) -> String? {
        label(bodyChartPants, SizingEngine.recommend(product: bodyChartPants, profile: profile(waist: waist)))
    }
    #expect(pick(74) == "30 / Regular")
    #expect(pick(78.9) == "30 / Regular")
    #expect(pick(79.1) == "32 / Regular")
    #expect(pick(84) == "34 / Regular")
    #expect(pick(84.1) == "34 / Regular")
    #expect(pick(60) == "30 / Regular")
    #expect(pick(100) == "34 / Regular")
    let rec = SizingEngine.recommend(product: bodyChartPants, profile: profile(waist: 79))
    #expect(rec.variantID != nil)
    #expect(rec.comparisons.first?.basis == .bodyChart)
}

@Test func secondaryComparisonsAppear() {
    let rec = SizingEngine.recommend(product: garmentTop, profile: profile(chest: 98, sleeve: 64))
    #expect(Set(rec.comparisons.map(\.kind)) == [.chest, .sleeve])
    let trouser = SizingFixtures.multiMeasurementPants
    let pants = SizingEngine.recommend(product: trouser, profile: profile(waist: 82, hips: 104, inseam: 77))
    #expect(Set(pants.comparisons.map(\.kind)) == [.waist, .hips, .inseam])
    #expect(label(trouser, pants) == "M")
}

@Test func unitConversionRoundTrips() {
    for kind in MeasurementKind.allCases {
        for value in [50.0, 98.0, 178.5] {
            let display = Units.toDisplay(value, kind: kind, units: .imperial)
            #expect(abs(Units.toMetric(display, kind: kind, units: .imperial) - value) < 1e-9)
            #expect(Units.toDisplay(value, kind: kind, units: .metric) == value)
        }
    }
    #expect(Units.format(178, kind: .height, units: .imperial) == "5 ft 10 in")
    #expect(Units.format(75, kind: .weight, units: .metric) == "75 kg")
    #expect(Units.unitLabel(kind: .weight, units: .imperial) == "lb")
}

@Test func demoProfileSuggestionsForEveryProduct() {
    let demo = profile(chest: 98, waist: 82)
    for p in SeedCatalog.products {
        let rec = SizingEngine.recommend(product: p, profile: demo)
        #expect(rec.variantID.flatMap(p.variant) != nil)
        #expect(rec.variantID.flatMap(p.variant)?.inStock == true)
        print("DEMO \(p.id): \(label(p, rec) ?? "nil") \(rec.confidence) | \(rec.headline) | \(rec.summary)")
    }
}
