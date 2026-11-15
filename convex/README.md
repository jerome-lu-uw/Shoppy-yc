# Shoppy backend (Convex)

Guest sandbox: there is no sign-in. The app generates a random `ownerId` once and sends it with every private call. This separates guests from each other but is **not secure**: anyone who has an owner's ID can read and write that owner's rows. Do not enable production payments without real authentication and fulfillment.

Checkout uses Whop's sandbox only. `checkout:start` recomputes the total from Convex catalog prices, creates an idempotent pending order, and returns a Whop-hosted sandbox checkout URL. The app treats the order as paid only after `/webhooks/whop` verifies Whop's signature and validates the account, checkout configuration, currency, subtotal, and order metadata. A browser return never confirms payment. Nothing in this integration purchases clothing or triggers shipment.

## Whop sandbox setup

1. Create a separate account at [sandbox.whop.com](https://sandbox.whop.com). Sandbox and production credentials look alike but are not interchangeable.
2. Create a hidden Shoppy product, enable shipping-address collection, and copy its `prod_` ID and the sandbox account's `biz_` ID.
3. Create a sandbox account API key that can create checkout configurations and one-time variants. Revoke any key exposed in chat, logs, or source control.
4. Set `WHOP_API_KEY`, `WHOP_ACCOUNT_ID`, and `WHOP_PRODUCT_ID` in the Convex deployment environment. Never add them to the iOS target, a plist, or a tracked environment file.
5. Deploy the Convex functions, then register `https://<deployment>.convex.site/webhooks/whop` in the Whop sandbox for `payment.succeeded` and `payment.failed`. Pin webhook payloads to API version `2026-11-14-1`.
6. Whop shows the webhook's `ws_` signing secret once. Save it as `WHOP_WEBHOOK_SECRET` in the Convex deployment environment.

Use Whop's sandbox cards to verify the complete flow:

- `4242 4242 4242 4242`: successful payment
- `4000 0000 0000 0002`: declined payment
- Any future expiry date and test CVC accepted by Whop

The checkout action is hard-wired to `WhopEnvironment.Sandbox` and rejects any checkout URL outside `sandbox.whop.com`.

## Commands (run from the repository root, Node at /opt/homebrew/bin)

- `npm install`
- `npm run typecheck`: type-check the functions
- `npx convex dev --once`: push functions to the dev deployment.
- `npm run seed`: re-seed the catalog from `ShoppyCore`'s `SeedCatalog` (idempotent upsert by product id). Run it again after the catalog changes.
- `npx convex run catalog:list`: show the seeded products.
- `npx convex run orders:clearOwner '{"ownerId":"<id>"}'`: delete one owner's rows (internal, CLI only).

The public deployment URL lives in `Shoppy/Backend/ConvexConfig.plist`. `.env.local` and deploy keys are gitignored.
