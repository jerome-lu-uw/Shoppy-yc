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
        Product(
            id: "marlowe-pine-harbor-rib-ls-oat",
            brand: "Marlowe & Pine",
            name: "Harbor Rib Long-Sleeve",
            category: .top,
            collection: .women,
            colorName: "Oat",
            priceCents: 5800,
            tagline: "Ribbed stretch. Easy layers.",
            details: ["Stretch cotton rib · Fitted cut", "Cold wash · Fictional demo specification"],
            previewAsset: "look-oat-charcoal",
            hasStretch: true,
            variants: [
                ProductVariant(id: "marlowe-pine-harbor-rib-ls-oat-xs", sizeLabel: "XS", garment: GarmentDimensions(chest: 90, sleeve: 58, length: 60)),
                ProductVariant(id: "marlowe-pine-harbor-rib-ls-oat-s", sizeLabel: "S", garment: GarmentDimensions(chest: 98, sleeve: 60, length: 62)),
                ProductVariant(id: "marlowe-pine-harbor-rib-ls-oat-m", sizeLabel: "M", garment: GarmentDimensions(chest: 106, sleeve: 62, length: 64)),
                ProductVariant(id: "marlowe-pine-harbor-rib-ls-oat-l", sizeLabel: "L", garment: GarmentDimensions(chest: 114, sleeve: 64, length: 66)),
            ]
        ),
        Product(
            id: "ridgeway-waffle-henley-moss",
            brand: "Ridgeway",
            name: "Waffle Henley Long-Sleeve",
            category: .top,
            collection: .men,
            colorName: "Moss",
            priceCents: 7400,
            tagline: "Textured cotton. Weekend weight.",
            details: ["Waffle-knit cotton · Regular cut", "Cold wash · Fictional demo specification"],
            previewAsset: "look-moss-stone",
            variants: [
                ProductVariant(id: "ridgeway-waffle-henley-moss-s", sizeLabel: "S", garment: GarmentDimensions(chest: 102, sleeve: 63, length: 69)),
                ProductVariant(id: "ridgeway-waffle-henley-moss-m", sizeLabel: "M", inStock: false, garment: GarmentDimensions(chest: 110, sleeve: 65, length: 71)),
                ProductVariant(id: "ridgeway-waffle-henley-moss-l", sizeLabel: "L", garment: GarmentDimensions(chest: 118, sleeve: 67, length: 73)),
            ]
        ),
        Product(
            id: "oakhaven-studio-wide-pant-clay",
            brand: "Oakhaven",
            name: "Studio Wide-Leg Pant",
            category: .pants,
            collection: .women,
            colorName: "Clay",
            priceCents: 10800,
            tagline: "Full length. Easy drape.",
            details: ["Stretch crepe · Wide leg", "Cold wash · Fictional demo specification"],
            previewAsset: "look-ivory-clay-wide",
            hasStretch: true,
            variants: [
                ProductVariant(id: "oakhaven-studio-wide-pant-clay-s", sizeLabel: "S", garment: GarmentDimensions(waist: 78, hips: 100, inseam: 76)),
                ProductVariant(id: "oakhaven-studio-wide-pant-clay-m", sizeLabel: "M", garment: GarmentDimensions(waist: 84, hips: 106, inseam: 77)),
                ProductVariant(id: "oakhaven-studio-wide-pant-clay-l", sizeLabel: "L", garment: GarmentDimensions(waist: 90, hips: 112, inseam: 78)),
            ]
        ),
        Product(
            id: "juniper-row-quiet-knit-ls-sage",
            brand: "Juniper Row",
            name: "Quiet Knit Long-Sleeve",
            category: .top,
            collection: .all,
            colorName: "Sage",
            priceCents: 8600,
            tagline: "Fine knit. Quiet colour.",
            details: ["Merino blend · Relaxed cut", "Hand wash · Fictional demo specification"],
            variants: [
                ProductVariant(id: "juniper-row-quiet-knit-ls-sage-s", sizeLabel: "S"),
                ProductVariant(id: "juniper-row-quiet-knit-ls-sage-m", sizeLabel: "M"),
                ProductVariant(id: "juniper-row-quiet-knit-ls-sage-l", sizeLabel: "L"),
            ]
        ),
    ]
}
