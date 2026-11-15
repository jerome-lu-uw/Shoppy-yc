import { defineSchema, defineTable } from "convex/server";
import { v } from "convex/values";

// GUEST DEMO, NOT SECURE: there is no authentication. `ownerId` is a random UUID the app
// generates once and keeps; anyone who knows or guesses it can read and write that owner's rows.
// Every private function filters by it, which separates guests from each other, nothing more.

export const sizeRange = v.object({ min: v.number(), max: v.number() });

export const variant = v.object({
  id: v.string(),
  sizeLabel: v.string(),
  inStock: v.boolean(),
  bodyChart: v.optional(
    v.object({
      chest: v.optional(sizeRange),
      waist: v.optional(sizeRange),
      hips: v.optional(sizeRange),
      inseam: v.optional(sizeRange),
    }),
  ),
  garment: v.optional(
    v.object({
      chest: v.optional(v.number()),
      waist: v.optional(v.number()),
      hips: v.optional(v.number()),
      inseam: v.optional(v.number()),
      sleeve: v.optional(v.number()),
      length: v.optional(v.number()),
    }),
  ),
});

export const product = v.object({
  productId: v.string(),
  brand: v.string(),
  name: v.string(),
  category: v.union(v.literal("top"), v.literal("pants")),
  collection: v.union(v.literal("women"), v.literal("men"), v.literal("all")),
  colorName: v.string(),
  priceCents: v.number(),
  tagline: v.string(),
  details: v.array(v.string()),
  imageURL: v.optional(v.string()),
  sourceURL: v.optional(v.string()),
  previewAsset: v.optional(v.string()),
  hasStretch: v.boolean(),
  isFictional: v.boolean(),
  variants: v.array(variant),
});

export const measurement = v.object({
  value: v.number(),
  source: v.union(v.literal("entered"), v.literal("estimated")),
  updatedAt: v.number(),
});

export const orderLine = v.object({
  productID: v.string(),
  variantID: v.string(),
  title: v.string(),
  sizeLabel: v.string(),
  quantity: v.number(),
  unitPriceCents: v.number(),
});

export default defineSchema({
  products: defineTable(product).index("by_productId", ["productId"]),
  profiles: defineTable({
    ownerId: v.string(),
    name: v.string(),
    measurements: v.record(v.string(), measurement),
    fitPreference: v.union(v.literal("close"), v.literal("regular"), v.literal("relaxed")),
    collection: v.union(v.literal("women"), v.literal("men"), v.literal("all")),
    units: v.union(v.literal("metric"), v.literal("imperial")),
    version: v.number(),
  }).index("by_owner", ["ownerId"]),
  likes: defineTable({
    ownerId: v.string(),
    productId: v.string(),
    likedAt: v.number(),
  })
    .index("by_owner", ["ownerId"])
    .index("by_owner_product", ["ownerId", "productId"]),
  cartItems: defineTable({
    ownerId: v.string(),
    itemId: v.string(),
    productID: v.string(),
    variantID: v.string(),
    quantity: v.number(),
    sizeSource: v.union(v.literal("suggested"), v.literal("userChosen")),
    needsSizeReview: v.boolean(),
    profileVersion: v.number(),
  })
    .index("by_owner", ["ownerId"])
    .index("by_owner_item", ["ownerId", "itemId"]),
  orders: defineTable({
    ownerId: v.string(),
    idempotencyKey: v.string(),
    number: v.string(),
    lines: v.array(orderLine),
    totalCents: v.number(),
    status: v.union(v.literal("confirmed"), v.literal("preparing"), v.literal("shipped")),
    isDemo: v.literal(true),
    createdAt: v.number(),
  })
    .index("by_owner", ["ownerId"])
    .index("by_owner_key", ["ownerId", "idempotencyKey"]),
});
