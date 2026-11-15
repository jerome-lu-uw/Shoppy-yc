import { mutation, query } from "./_generated/server";
import { v } from "convex/values";
import { product } from "./schema";

export const list = query({
  args: {},
  handler: async (ctx) => ctx.db.query("products").collect(),
});

export const seed = mutation({
  args: { products: v.array(product) },
  handler: async (ctx, { products }) => {
    let inserted = 0;
    let updated = 0;
    for (const p of products) {
      const existing = await ctx.db
        .query("products")
        .withIndex("by_productId", (q) => q.eq("productId", p.productId))
        .unique();
      if (existing) {
        await ctx.db.replace(existing._id, p);
        updated++;
      } else {
        await ctx.db.insert("products", p);
        inserted++;
      }
    }
    return { inserted, updated };
  },
});
