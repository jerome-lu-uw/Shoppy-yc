import { mutation, query } from "./_generated/server";
import { v } from "convex/values";

export const list = query({
  args: { ownerId: v.string() },
  handler: async (ctx, { ownerId }) =>
    ctx.db.query("cartItems").withIndex("by_owner", (q) => q.eq("ownerId", ownerId)).collect(),
});

export const upsert = mutation({
  args: {
    ownerId: v.string(),
    itemId: v.string(),
    productID: v.string(),
    variantID: v.string(),
    quantity: v.number(),
    sizeSource: v.union(v.literal("suggested"), v.literal("userChosen")),
    needsSizeReview: v.boolean(),
    profileVersion: v.number(),
  },
  handler: async (ctx, args) => {
    if (!Number.isInteger(args.quantity) || args.quantity < 1 || args.quantity > 99) {
      throw new Error("Quantity must be a whole number from 1 to 99.");
    }
    const existing = await ctx.db
      .query("cartItems")
      .withIndex("by_owner_item", (q) => q.eq("ownerId", args.ownerId).eq("itemId", args.itemId))
      .unique();
    if (existing) {
      await ctx.db.replace(existing._id, args);
    } else {
      await ctx.db.insert("cartItems", args);
    }
  },
});

export const remove = mutation({
  args: { ownerId: v.string(), itemId: v.string() },
  handler: async (ctx, { ownerId, itemId }) => {
    const rows = await ctx.db
      .query("cartItems")
      .withIndex("by_owner_item", (q) => q.eq("ownerId", ownerId).eq("itemId", itemId))
      .collect();
    for (const row of rows) await ctx.db.delete(row._id);
  },
});
