import { unwrapWebhook } from "@whop/sdk/helpers";
import { httpRouter } from "convex/server";
import { internal } from "./_generated/api";
import { httpAction } from "./_generated/server";

type WhopEvent = {
  id?: unknown;
  type?: unknown;
  account_id?: unknown;
  company_id?: unknown;
  data?: unknown;
};

type WhopPayment = {
  id?: unknown;
  account_id?: unknown;
  checkout_configuration_id?: unknown;
  currency?: unknown;
  failure_message?: unknown;
  metadata?: unknown;
  status?: unknown;
  substatus?: unknown;
  subtotal?: unknown;
};

const http = httpRouter();

http.route({
  path: "/webhooks/whop",
  method: "POST",
  handler: httpAction(async (ctx, request) => {
    const webhookSecret = process.env.WHOP_WEBHOOK_SECRET?.trim();
    const expectedAccountID = process.env.WHOP_ACCOUNT_ID?.trim();
    if (!webhookSecret?.startsWith("ws_") || !expectedAccountID?.startsWith("biz_")) {
      return new Response("Webhook is not configured.", { status: 500 });
    }

    const payload = await request.text();
    let event: WhopEvent;
    try {
      const headers: Record<string, string> = {};
      request.headers.forEach((value, key) => {
        headers[key] = value;
      });
      event = unwrapWebhook<WhopEvent>(payload, {
        headers,
        key: webhookSecret,
      });
    } catch {
      return new Response("Invalid webhook signature.", { status: 400 });
    }

    if (event.type !== "payment.succeeded" && event.type !== "payment.failed") {
      return new Response("Ignored.", { status: 200 });
    }

    try {
      const eventID = requiredString(event.id, "event ID");
      const envelopeAccountID = requiredString(event.account_id ?? event.company_id, "account ID");
      const payment = requiredObject(event.data, "payment") as WhopPayment;
      const paymentAccountID = requiredString(payment.account_id, "payment account ID");
      if (envelopeAccountID !== expectedAccountID || paymentAccountID !== expectedAccountID) {
        throw new Error("Webhook account does not match.");
      }
      if (event.type === "payment.succeeded") {
        if (payment.status !== "paid" || payment.substatus !== "succeeded") {
          throw new Error("Successful webhook does not contain a paid payment.");
        }
      }

      const metadata = requiredObject(payment.metadata, "payment metadata");
      const subtotal = requiredObject(payment.subtotal, "payment subtotal");
      const subtotalCurrency = requiredString(subtotal.currency, "subtotal currency");
      const paymentCurrency = requiredString(payment.currency, "payment currency");
      if (subtotalCurrency !== paymentCurrency) throw new Error("Payment currencies do not match.");

      await ctx.runMutation(internal.orders.applyWhopEvent, {
        eventId: eventID,
        eventType: event.type,
        orderId: requiredString(metadata.shoppy_order_id, "Shoppy order ID"),
        paymentID: requiredString(payment.id, "payment ID"),
        checkoutConfigurationID: requiredString(
          payment.checkout_configuration_id,
          "checkout configuration ID",
        ),
        currency: paymentCurrency,
        subtotalCents: moneyToCents(requiredString(subtotal.amount, "subtotal amount")),
        failureMessage:
          typeof payment.failure_message === "string" ? payment.failure_message : undefined,
      });
      return new Response("OK", { status: 200 });
    } catch (error) {
      console.error("Whop webhook rejected:", error instanceof Error ? error.message : "Unknown error");
      return new Response("Invalid webhook payload.", { status: 400 });
    }
  }),
});

function requiredObject(value: unknown, name: string): Record<string, unknown> {
  if (!value || typeof value !== "object" || Array.isArray(value)) throw new Error(`Missing ${name}.`);
  return value as Record<string, unknown>;
}

function requiredString(value: unknown, name: string): string {
  if (typeof value !== "string" || !value.trim()) throw new Error(`Missing ${name}.`);
  return value;
}

function moneyToCents(value: string): number {
  const match = /^(\d+)(?:\.(\d{1,2}))?$/.exec(value);
  if (!match) throw new Error("Invalid money amount.");
  const cents = Number(match[1]) * 100 + Number((match[2] ?? "").padEnd(2, "0"));
  if (!Number.isSafeInteger(cents)) throw new Error("Money amount is too large.");
  return cents;
}

export default http;
