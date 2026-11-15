import { internalMutation, query } from "./_generated/server";
import { v } from "convex/values";
import { checkoutCartItem } from "./schema";

export const list = query({
  args: { ownerId: v.string() },
  handler: async (ctx, { ownerId }) => {
    const rows = await ctx.db.query("orders").withIndex("by_owner", (q) => q.eq("ownerId", ownerId)).collect();
    return rows.sort((a, b) => b.createdAt - a.createdAt);
  },
});

export const get = query({
  args: { ownerId: v.string(), orderId: v.id("orders") },
  handler: async (ctx, { ownerId, orderId }) => {
    const order = await ctx.db.get(orderId);
    return order?.ownerId === ownerId ? order : null;
  },
});

export const prepareCheckout = internalMutation({
  args: {
    ownerId: v.string(),
    idempotencyKey: v.string(),
    items: v.array(checkoutCartItem),
  },
  handler: async (ctx, { ownerId, idempotencyKey, items }) => {
    if (!ownerId.trim()) throw new Error("Missing checkout owner.");
    if (idempotencyKey.length < 16 || idempotencyKey.length > 255) throw new Error("Invalid idempotency key.");

    const existing = await ctx.db
      .query("orders")
      .withIndex("by_owner_key", (q) => q.eq("ownerId", ownerId).eq("idempotencyKey", idempotencyKey))
      .unique();
    if (existing) {
      if (existing.status === "paymentFailed" && existing.checkoutURL) {
        await ctx.db.patch(existing._id, {
          status: "pendingPayment",
          failureMessage: undefined,
          updatedAt: Date.now(),
        });
        return (await ctx.db.get(existing._id))!;
      }
      return existing;
    }

    if (items.length === 0) throw new Error("The bag is empty.");
    if (items.length > 50) throw new Error("A checkout can contain at most 50 bag items.");

    const itemIDs = new Set<string>();
    const priced: {
      productID: string;
      variantID: string;
      title: string;
      sizeLabel: string;
      quantity: number;
      unitPriceCents: number;
    }[] = [];
    let totalCents = 0;
    for (const item of items) {
      if (!item.itemId.trim() || itemIDs.has(item.itemId)) throw new Error("Duplicate bag item.");
      itemIDs.add(item.itemId);
      if (!Number.isInteger(item.quantity) || item.quantity < 1 || item.quantity > 99) {
        throw new Error("Quantity must be a whole number from 1 to 99.");
      }
      const product = await ctx.db
        .query("products")
        .withIndex("by_productId", (q) => q.eq("productId", item.productID))
        .unique();
      const variant = product?.variants.find((x) => x.id === item.variantID);
      if (!product || !variant) throw new Error("Unknown product or size.");
      if (!variant.inStock) throw new Error(product.name + " in " + variant.sizeLabel + " is out of stock.");
      if (!Number.isInteger(product.priceCents) || product.priceCents < 1) throw new Error("Invalid catalog price.");
      totalCents += product.priceCents * item.quantity;
      priced.push({
        productID: product.productId,
        variantID: variant.id,
        title: product.name,
        sizeLabel: variant.sizeLabel,
        quantity: item.quantity,
        unitPriceCents: product.priceCents,
      });
    }

    const suffix = idempotencyKey.replace(/[^a-zA-Z0-9]/g, "").slice(-8).toUpperCase();
    const now = Date.now();
    const id = await ctx.db.insert("orders", {
      ownerId,
      idempotencyKey,
      number: "SH-" + suffix,
      lines: priced,
      totalCents,
      currency: "usd",
      status: "pendingPayment",
      environment: "sandbox",
      cartItems: items,
      createdAt: now,
      updatedAt: now,
    });

    return (await ctx.db.get(id))!;
  },
});

export const attachCheckout = internalMutation({
  args: {
    orderId: v.id("orders"),
    checkoutURL: v.string(),
    checkoutConfigurationID: v.string(),
    variantID: v.optional(v.string()),
  },
  handler: async (ctx, args) => {
    const order = await ctx.db.get(args.orderId);
    if (!order) throw new Error("Checkout order not found.");
    const url = new URL(args.checkoutURL);
    if (url.protocol !== "https:" || url.hostname !== "sandbox.whop.com") {
      throw new Error("Whop returned a non-sandbox checkout URL.");
    }
    if (
      order.whopCheckoutConfigurationID &&
      order.whopCheckoutConfigurationID !== args.checkoutConfigurationID
    ) {
      throw new Error("Checkout configuration does not match the pending order.");
    }
    await ctx.db.patch(args.orderId, {
      checkoutURL: args.checkoutURL,
      whopCheckoutConfigurationID: args.checkoutConfigurationID,
      whopVariantID: args.variantID,
      updatedAt: Date.now(),
    });
    return (await ctx.db.get(args.orderId))!;
  },
});

export const applyWhopEvent = internalMutation({
  args: {
    eventId: v.string(),
    eventType: v.union(v.literal("payment.succeeded"), v.literal("payment.failed")),
    orderId: v.string(),
    paymentID: v.string(),
    checkoutConfigurationID: v.string(),
    currency: v.string(),
    subtotalCents: v.number(),
    failureMessage: v.optional(v.string()),
  },
  handler: async (ctx, event) => {
    const duplicate = await ctx.db
      .query("whopEvents")
      .withIndex("by_event", (q) => q.eq("eventId", event.eventId))
      .unique();
    if (duplicate) return { duplicate: true };

    const orderId = ctx.db.normalizeId("orders", event.orderId);
    if (!orderId) throw new Error("Webhook order ID is invalid.");
    const order = await ctx.db.get(orderId);
    if (!order || order.environment !== "sandbox") throw new Error("Webhook order not found.");
    if (!order.whopCheckoutConfigurationID) throw new Error("Order has no Whop checkout.");
    if (order.whopCheckoutConfigurationID !== event.checkoutConfigurationID) {
      throw new Error("Webhook checkout does not match the order.");
    }
    if (event.currency.toLowerCase() !== order.currency || event.subtotalCents !== order.totalCents) {
      throw new Error("Webhook amount or currency does not match the order.");
    }

    if (event.eventType === "payment.succeeded") {
      if (order.status === "paid" && order.whopPaymentID !== event.paymentID) {
        throw new Error("Order is already associated with another payment.");
      }
      if (order.status !== "paid") {
        const clearedCartItemIDs = (order.cartItems ?? []).map((item) => item.itemId);
        for (const snapshot of order.cartItems ?? []) {
          const cartItem = await ctx.db
            .query("cartItems")
            .withIndex("by_owner_item", (q) => q.eq("ownerId", order.ownerId).eq("itemId", snapshot.itemId))
            .unique();
          if (
            cartItem &&
            cartItem.productID === snapshot.productID &&
            cartItem.variantID === snapshot.variantID &&
            cartItem.quantity === snapshot.quantity
          ) {
            await ctx.db.delete(cartItem._id);
          }
        }
        const now = Date.now();
        await ctx.db.patch(orderId, {
          status: "paid",
          whopPaymentID: event.paymentID,
          clearedCartItemIDs,
          failureMessage: undefined,
          paidAt: now,
          updatedAt: now,
        });
      }
    } else if (order.status !== "paid") {
      await ctx.db.patch(orderId, {
        status: "paymentFailed",
        whopPaymentID: event.paymentID,
        failureMessage: event.failureMessage?.slice(0, 500) || "Whop could not complete the sandbox payment.",
        updatedAt: Date.now(),
      });
    }

    await ctx.db.insert("whopEvents", {
      eventId: event.eventId,
      type: event.eventType,
      orderId,
      paymentID: event.paymentID,
      createdAt: Date.now(),
    });
    return { duplicate: false };
  },
});

export const clearOwner = internalMutation({
  args: { ownerId: v.string() },
  handler: async (ctx, { ownerId }) => {
    const orders = await ctx.db.query("orders").withIndex("by_owner", (q) => q.eq("ownerId", ownerId)).collect();
    for (const order of orders) {
      const events = await ctx.db
        .query("whopEvents")
        .withIndex("by_order", (q) => q.eq("orderId", order._id))
        .collect();
      for (const event of events) await ctx.db.delete(event._id);
      await ctx.db.delete(order._id);
    }
    for (const table of ["profiles", "likes", "cartItems"] as const) {
      const rows = await ctx.db.query(table).withIndex("by_owner", (q) => q.eq("ownerId", ownerId)).collect();
      for (const row of rows) await ctx.db.delete(row._id);
    }
  },
});
