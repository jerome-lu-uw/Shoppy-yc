import Foundation

/// Sourced products shown in the app's default catalog.
public enum SeedCatalog {
    public static let products: [Product] = [
        Product(
            id: "lululemon-smooth-spacer-quarter-zip-moonlit-green",
            brand: "lululemon",
            name: "Smooth Spacer Quarter Zip",
            category: .top,
            collection: .men,
            colorName: "Moonlit Green",
            priceCents: 13800,
            tagline: "Instant recovery mode.",
            details: [
                "Classic fit · Room in the chest and at the waist",
                "Soft modal-blend fabric · Four-way stretch · Quick-drying",
                "Soft outside, smooth inside · Weighty feel that stands slightly away from the body",
                "Body: 58% recycled polyester, 34% modal, 8% elastane",
                "Locker loop · Machine wash cold",
            ],
            sourceURL: URL(string: "https://shop.lululemon.com/p/smooth-spacer-quarter-zip/yrj7r7r4cc?fp=1&color=80064"),
            previewAsset: "look-smooth-spacer-quarter-zip",
            hasStretch: true,
            isFictional: false,
            variants: [
                ProductVariant(id: "lululemon-smooth-spacer-quarter-zip-green-xs", sizeLabel: "XS"),
                ProductVariant(id: "lululemon-smooth-spacer-quarter-zip-green-s", sizeLabel: "S"),
                ProductVariant(id: "lululemon-smooth-spacer-quarter-zip-green-m", sizeLabel: "M"),
                ProductVariant(id: "lululemon-smooth-spacer-quarter-zip-green-l", sizeLabel: "L"),
                ProductVariant(id: "lululemon-smooth-spacer-quarter-zip-green-xl", sizeLabel: "XL"),
                ProductVariant(id: "lululemon-smooth-spacer-quarter-zip-green-xxl", sizeLabel: "XXL"),
            ]
        ),
        Product(
            id: "lululemon-cotton-blend-waffle-knit-long-sleeve-club-blue",
            brand: "lululemon",
            name: "Cotton-Blend Waffle-Knit Long Sleeve",
            category: .top,
            collection: .men,
            colorName: "Club Blue",
            priceCents: 7800,
            tagline: "Low-key timeless.",
            details: [
                "Relaxed fit · Extra room in the chest and at the waist",
                "Warm, weighty waffle knit · Four-way stretch · Soft texture",
                "Body: 58% organic cotton, 37% recycled polyester, 5% elastane",
                "Rib: 56% recycled polyester, 41% organic cotton, 3% elastane",
                "Locker loop · Machine wash cold",
            ],
            imageURL: URL(string: "https://images.lululemon.com/is/image/lululemon/LM3HF7S_068578_1"),
            sourceURL: URL(string: "https://shop.lululemon.com/p/cotton-blend-waffle-knit-long-sleeve/o0gq5sxku4?fp=1&color=68578"),
            previewAsset: "look-cotton-blend-waffle-knit-long-sleeve-club-blue",
            hasStretch: true,
            isFictional: false,
            variants: mensTopVariants("lululemon-cotton-blend-waffle-knit-long-sleeve-club-blue")
        ),
        Product(
            id: "lululemon-everyday-cotton-blend-classic-t-shirt-black",
            brand: "lululemon",
            name: "Everyday Cotton-Blend Classic T-Shirt",
            category: .top,
            collection: .men,
            colorName: "Black",
            priceCents: 5800,
            tagline: "Perfect tees start with great fabric.",
            details: [
                "Classic fit · Room in the chest and at the waist",
                "Soft Pima cotton blend · Breathable · Sweat-wicking · Quick-drying",
                "Body: 37% organic Pima cotton, 27% lyocell, 27% recycled polyester, 9% elastane",
                "Rib: 38% organic Pima cotton, 29% recycled polyester, 28% lyocell, 5% elastane",
                "Machine wash cold",
            ],
            imageURL: URL(string: "https://images.lululemon.com/is/image/lululemon/LM3GTOS_0001_1"),
            sourceURL: URL(string: "https://shop.lululemon.com/p/everyday-cotton-blend-classic-t-shirt/owzvguq0v2?fp=1&color=0001"),
            previewAsset: "look-everyday-cotton-blend-classic-t-shirt-black",
            hasStretch: true,
            isFictional: false,
            variants: mensTopVariants("lululemon-everyday-cotton-blend-classic-t-shirt-black")
        ),
        Product(
            id: "lululemon-easyset-training-sleeveless-shirt-black",
            brand: "lululemon",
            name: "EasySet Training Sleeveless Shirt",
            category: .top,
            collection: .men,
            colorName: "Black",
            priceCents: 6800,
            tagline: "Go boldly.",
            details: [
                "Relaxed fit · Extra room in the chest and at the waist",
                "Lightweight · Sweat-wicking · Quick-drying · Naturally breathable",
                "Body: 83% recycled polyester, 10% lyocell, 7% Lycra elastane",
                "Rib: 81% recycled polyester, 10% lyocell, 9% Lycra elastane",
                "Ribbed collar · Locker loop · No-Stink Zinc™ treatment",
            ],
            imageURL: URL(string: "https://images.lululemon.com/is/image/lululemon/LM1368S_0001_1"),
            sourceURL: URL(string: "https://shop.lululemon.com/p/easyset-training-sleeveless-shirt-graphic/vtyhs4myy6?fp=1&color=0001"),
            previewAsset: "look-easyset-training-sleeveless-shirt-black",
            hasStretch: true,
            isFictional: false,
            variants: mensTopVariants(
                "lululemon-easyset-training-sleeveless-shirt-black",
                includes3XL: true,
                soldOut: ["3XL"]
            )
        ),
    ]

    private static func mensTopVariants(
        _ productID: String,
        includes3XL: Bool = false,
        soldOut: Set<String> = []
    ) -> [ProductVariant] {
        let rows: [(label: String, minimum: Double, maximum: Double)] = [
            ("XS", 35, 36),
            ("S", 37, 38),
            ("M", 39, 40),
            ("L", 41, 42),
            ("XL", 43, 45),
            ("XXL", 46, 48),
            ("3XL", 49, 51),
        ]
        return rows
            .filter { includes3XL || $0.label != "3XL" }
            .map { row in
                ProductVariant(
                    id: "\(productID)-\(row.label.lowercased())",
                    sizeLabel: row.label,
                    inStock: !soldOut.contains(row.label),
                    bodyChart: BodyChart(
                        chest: SizeRange(min: row.minimum * 2.54, max: row.maximum * 2.54)
                    )
                )
            }
    }
}
