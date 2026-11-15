import { WhopClient, WhopEnvironment } from "@whop/sdk";
import { v } from "convex/values";
import { internal } from "./_generated/api";
import type { Doc } from "./_generated/dataModel";
import { action } from "./_generated/server";
import { checkoutCartItem } from "./schema";

const apiVersionDate = "2026-11-14-1";

export const start = action({
  args: {
    ownerId: v.string(),
    idempotencyKey: v.string(),
    items: v.array(checkoutCartItem),
  },
  handler: async (ctx, args): Promise<{ order: Doc<"orders">; checkoutURL: string }> => {
    const pendingOrder: Doc<"orders"> = await ctx.runMutation(internal.orders.prepareCheckout, args);
    if (pendingOrder.checkoutURL) {
      return { order: pendingOrder, checkoutURL: pendingOrder.checkoutURL };
    }

    const apiKey = requiredEnvironmentValue("WHOP_API_KEY");
    const accountID = requiredEnvironmentValue("WHOP_ACCOUNT_ID", "biz_");
    const productID = requiredEnvironmentValue("WHOP_PRODUCT_ID", "prod_");
    const whop = new WhopClient({
      token: apiKey,
      environment: WhopEnvironment.Sandbox,
      apiVersionDate,
    });
    const description = pendingOrder.lines
      .map((line) => `${line.quantity}× ${line.title} (${line.sizeLabel})`)
      .join(", ")
      .slice(0, 1_000);
    const checkout = await whop.checkoutConfigurations.create(
      {
        account_id: accountID,
        mode: "payment",
        metadata: {
          shoppy_order_id: pendingOrder._id,
          shoppy_order_number: pendingOrder.number,
          shoppy_environment: "sandbox",
        },
        variant: {
          account_id: accountID,
          billing_type: "one_time",
          currency: "usd",
          description,
          force_create_new_plan: true,
          initial_price: pendingOrder.totalCents / 100,
          product_id: productID,
          release_method: "buy_now",
          title: `Shoppy sandbox order ${pendingOrder.number}`,
          unlimited_stock: true,
          visibility: "hidden",
        },
      },
      { idempotencyKey: `shoppy_${pendingOrder._id}` },
    );

    if (checkout.account_id !== accountID) throw new Error("Whop checkout belongs to an unexpected account.");
    if (!checkout.purchase_url) throw new Error("Whop did not return a checkout URL.");
    const order: Doc<"orders"> = await ctx.runMutation(internal.orders.attachCheckout, {
      orderId: pendingOrder._id,
      checkoutURL: checkout.purchase_url,
      checkoutConfigurationID: checkout.id,
      variantID: checkout.variant?.id,
    });
    return { order, checkoutURL: checkout.purchase_url };
  },
});

function requiredEnvironmentValue(name: string, prefix?: string): string {
  const value = process.env[name]?.trim();
  if (!value) throw new Error(`${name} is not configured.`);
  if (prefix && !value.startsWith(prefix)) throw new Error(`${name} has an invalid format.`);
  return value;
}
