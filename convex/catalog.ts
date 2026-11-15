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
    let deleted = 0;
    const productIDs = new Set(products.map((item) => item.productId));

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

    const existingProducts = await ctx.db.query("products").collect();
    for (const existing of existingProducts) {
      if (!productIDs.has(existing.productId)) {
        await ctx.db.delete(existing._id);
        deleted++;
      }
    }

    let deletedLikes = 0;
    const likes = await ctx.db.query("likes").collect();
    for (const like of likes) {
      if (!productIDs.has(like.productId)) {
        await ctx.db.delete(like._id);
        deletedLikes++;
      }
    }

    let deletedCartItems = 0;
    const cartItems = await ctx.db.query("cartItems").collect();
    for (const item of cartItems) {
      if (!productIDs.has(item.productID)) {
        await ctx.db.delete(item._id);
        deletedCartItems++;
      }
    }

    return { inserted, updated, deleted, deletedLikes, deletedCartItems };
  },
});
