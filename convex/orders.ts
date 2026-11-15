import { internalMutation, mutation, query } from "./_generated/server";
import { v } from "convex/values";

export const list = query({
  args: { ownerId: v.string() },
  handler: async (ctx, { ownerId }) => {
    const rows = await ctx.db.query("orders").withIndex("by_owner", (q) => q.eq("ownerId", ownerId)).collect();
    return rows.sort((a, b) => b.createdAt - a.createdAt);
  },
});

/** Simulated checkout: no payment provider is contacted and nothing ships. */
export const placeDemo = mutation({
  args: {
    ownerId: v.string(),
    idempotencyKey: v.string(),
    lines: v.array(
      v.object({
        productID: v.string(),
        variantID: v.string(),
        quantity: v.number(),
      }),
    ),
  },
  handler: async (ctx, { ownerId, idempotencyKey, lines }) => {
    const existing = await ctx.db
      .query("orders")
      .withIndex("by_owner_key", (q) => q.eq("ownerId", ownerId).eq("idempotencyKey", idempotencyKey))
      .unique();
    if (existing) return existing;

    if (lines.length === 0) throw new Error("The bag is empty.");

    const priced = [];
    let totalCents = 0;
    for (const line of lines) {
      if (!Number.isInteger(line.quantity) || line.quantity < 1 || line.quantity > 99) {
        throw new Error("Quantity must be a whole number from 1 to 99.");
      }
      const product = await ctx.db
        .query("products")
        .withIndex("by_productId", (q) => q.eq("productId", line.productID))
        .unique();
      const variant = product?.variants.find((x) => x.id === line.variantID);
      if (!product || !variant) throw new Error("Unknown product or size.");
      if (!variant.inStock) throw new Error(product.name + " in " + variant.sizeLabel + " is out of stock.");
      totalCents += product.priceCents * line.quantity;
      priced.push({
        productID: product.productId,
        variantID: variant.id,
        title: product.name,
        sizeLabel: variant.sizeLabel,
        quantity: line.quantity,
        unitPriceCents: product.priceCents,
      });
    }

    const count = (await ctx.db.query("orders").collect()).length;
    const id = await ctx.db.insert("orders", {
      ownerId,
      idempotencyKey,
      number: "SH-" + String(100 + count).padStart(5, "0"),
      lines: priced,
      totalCents,
      status: "confirmed",
      isDemo: true,
      createdAt: Date.now(),
    });

    const cart = await ctx.db.query("cartItems").withIndex("by_owner", (q) => q.eq("ownerId", ownerId)).collect();
    for (const item of cart) await ctx.db.delete(item._id);

    return (await ctx.db.get(id))!;
  },
});

/** Test cleanup, run from the CLI only: removes one owner's rows. */
export const clearOwner = internalMutation({
  args: { ownerId: v.string() },
  handler: async (ctx, { ownerId }) => {
    for (const table of ["profiles", "likes", "cartItems", "orders"] as const) {
      const rows = await ctx.db.query(table).withIndex("by_owner", (q) => q.eq("ownerId", ownerId)).collect();
      for (const row of rows) await ctx.db.delete(row._id);
    }
  },
});
