import Foundation

/// Fictional demo catalog matching the design frames. Every brand, price, and measurement here is invented.
public enum SeedCatalog {
    public static let products: [Product] = [
        Product(
            id: "northline-transit-ls-ink",
            brand: "Northline",
            name: "Transit Long-Sleeve",
            category: .top,
            collection: .all,
            colorName: "Ink",
            priceCents: 6800,
            tagline: "Soft structure. Easy movement.",
            details: ["Cotton blend · Regular cut", "Cold wash · Fictional demo specification"],
            previewAsset: "look-ink-stone",
            variants: [
                ProductVariant(id: "northline-transit-ls-ink-s", sizeLabel: "S", garment: GarmentDimensions(chest: 100, sleeve: 62, length: 68)),
                ProductVariant(id: "northline-transit-ls-ink-m", sizeLabel: "M", garment: GarmentDimensions(chest: 108, sleeve: 64, length: 70)),
                ProductVariant(id: "northline-transit-ls-ink-l", sizeLabel: "L", garment: GarmentDimensions(chest: 116, sleeve: 66, length: 72)),
            ]
        ),
        Product(
            id: "fieldform-everyday-pant-stone",
            brand: "Fieldform",
            name: "Everyday Straight Pant",
            category: .pants,
            collection: .all,
            colorName: "Stone",
            priceCents: 9200,
            tagline: "Soft structure. Easy movement.",
            details: ["Cotton twill · Straight leg", "Cold wash · Fictional demo specification"],
            previewAsset: "look-ink-stone",
            variants: [
                ProductVariant(id: "fieldform-everyday-pant-stone-30r", sizeLabel: "30 / Regular", bodyChart: BodyChart(waist: SizeRange(min: 74, max: 79))),
                ProductVariant(id: "fieldform-everyday-pant-stone-32r", sizeLabel: "32 / Regular", bodyChart: BodyChart(waist: SizeRange(min: 79, max: 84))),
                ProductVariant(id: "fieldform-everyday-pant-stone-34r", sizeLabel: "34 / Regular", bodyChart: BodyChart(waist: SizeRange(min: 84, max: 89))),
            ]
        ),
    ]
}
