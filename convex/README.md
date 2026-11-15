# Shoppy backend (Convex)

Guest demo: there is no sign-in. The app generates a random `ownerId` once and sends it with every private call. This separates guests from each other but is **not secure**: anyone who has an owner's id can read and write that owner's rows.

Checkout is simulated. `orders:placeDemo` recomputes the total from catalog prices, stores a demo order, clears the owner's cart, and never contacts a payment provider. Calling it again with the same `idempotencyKey` returns the existing order.

## Commands (run from the repository root, Node at /opt/homebrew/bin)

- `npm install`
- `npm run typecheck`: type-check the functions.
- `npx convex dev --once`: push functions to the dev deployment.
- `npm run seed`: re-seed the catalog from `ShoppyCore`'s `SeedCatalog` (idempotent upsert by product id). Run it again after the catalog changes.
- `npx convex run catalog:list`: show the seeded products.
- `npx convex run orders:clearOwner '{"ownerId":"<id>"}'`: delete one owner's rows (internal, CLI only).

The public deployment URL lives in `Shoppy/Backend/ConvexConfig.plist`. `.env.local` and deploy keys are gitignored.
