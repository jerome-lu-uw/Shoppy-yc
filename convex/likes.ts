import { mutation, query } from "./_generated/server";
import { v } from "convex/values";

export const list = query({
  args: { ownerId: v.string() },
  handler: async (ctx, { ownerId }) => {
    const rows = await ctx.db.query("likes").withIndex("by_owner", (q) => q.eq("ownerId", ownerId)).collect();
    return rows.sort((a, b) => a.likedAt - b.likedAt);
  },
});

export const set = mutation({
  args: { ownerId: v.string(), productId: v.string(), liked: v.boolean() },
  handler: async (ctx, { ownerId, productId, liked }) => {
    const rows = await ctx.db
      .query("likes")
      .withIndex("by_owner_product", (q) => q.eq("ownerId", ownerId).eq("productId", productId))
      .collect();
    if (!liked) {
      for (const row of rows) await ctx.db.delete(row._id);
      return;
    }
    if (rows.length === 0) await ctx.db.insert("likes", { ownerId, productId, likedAt: Date.now() });
  },
});
