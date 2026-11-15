import Testing
@testable import ShoppyCore

@Test func seedCatalogHasUniqueIDs() {
    let ids = SeedCatalog.products.map(\.id)
    #expect(Set(ids).count == ids.count)
    let variantIDs = SeedCatalog.products.flatMap(\.variants).map(\.id)
    #expect(Set(variantIDs).count == variantIDs.count)
}

@Test func placeholderRecommendationPicksAnInStockVariant() {
    let product = SeedCatalog.products[0]
    let recommendation = SizingEngine.recommend(product: product, profile: BodyProfile())
    #expect(product.variant(recommendation.variantID ?? "") != nil)
}
