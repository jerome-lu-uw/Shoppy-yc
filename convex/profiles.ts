import { mutation, query } from "./_generated/server";
import { v } from "convex/values";
import { measurement } from "./schema";

export const get = query({
  args: { ownerId: v.string() },
  handler: async (ctx, { ownerId }) =>
    ctx.db.query("profiles").withIndex("by_owner", (q) => q.eq("ownerId", ownerId)).unique(),
});

export const save = mutation({
  args: {
    ownerId: v.string(),
    name: v.string(),
    measurements: v.record(v.string(), measurement),
    fitPreference: v.union(v.literal("close"), v.literal("regular"), v.literal("relaxed")),
    collection: v.union(v.literal("women"), v.literal("men"), v.literal("all")),
    units: v.union(v.literal("metric"), v.literal("imperial")),
    version: v.number(),
  },
  handler: async (ctx, args) => {
    const existing = await ctx.db
      .query("profiles")
      .withIndex("by_owner", (q) => q.eq("ownerId", args.ownerId))
      .unique();
    if (existing) {
      await ctx.db.replace(existing._id, args);
    } else {
      await ctx.db.insert("profiles", args);
    }
  },
});
