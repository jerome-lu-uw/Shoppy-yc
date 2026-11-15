Shoppy — Sunday, November 15, 2026, 11 AM–8 PM Pacific

November 15 access update: free Capy Max will be provided at 10 AM Pacific. Confirm activation and included allowances then; use Capy for implementation and covered mobile tooling starting at 11 AM. Revyl and Convex remain free-only, with no paid overage or top-ups. This supersedes the earlier Capy availability blocker.

Budget update: [the free-tier build plan](free-tier-build-plan.md) supersedes paid cloud-build assumptions below. Build locally in Xcode; use Revyl directly within its free allowance. Capy participation requires a verified existing free/promotional entitlement because no public ongoing free plan was found.

This nine-hour demo plan supersedes the earlier 6–8 week implementation estimate for tomorrow. The broader execution plan and 22-screen Figma brief remain the product roadmap. Planning only; no application code has been started.

The required demonstration is Jerome's existing scan wearing at least one prepared outfit, interactive rotation, native USDZ AR floor placement, a small multi-gender retailer catalog, saving, a bag, mock checkout, and editable measurements. General automatic garment fitting across arbitrary uploads is outside the nine-hour commitment.

OpenAI credits can support image edits, visual references, and code-assisted procedural garment authoring. The official image API documents image output, not a direct calibrated body/garment-to-USDZ endpoint. A separate geometry creation/export pipeline is still required. Keep image previews explicitly separate from interactive 3D. Source: https://developers.openai.com/api/docs/guides/image-generation

Use the supplied scan as the reliable primary path. Prepare one top and one trouser mesh, using simple authored/procedural geometry if needed, aligned to that scan. Preserve the intended approximate appearance and label it Style preview. Never present an unchanged avatar as wearing a catalog item. Items without prepared 3D assets can show retailer photographs with Preview unavailable.

| Time, Pacific | Deliverable |
| --- | --- |
| 11:00–11:30 | Confirm Figma essentials; native app builds; connect Convex and Capy/Revyl access. |
| 11:30–1:30 | Highest-risk work: scan scale, garment overlay, composite USDZ, rotation and physical-device AR. |
| 1:30–2:30 | Discover/Saved/Bag/You shell, swipe and rotation modes. |
| 2:30–3:15 | Small catalog, Convex likes/profile/cart persistence. |
| 3:15–4:00 | Measurement editing and transparent rule-based suggested sizing. |
| 4:00–4:45 | Clearly labeled local mock checkout and order confirmation. |
| 4:45–5:30 | Profile/import polish; attempt capture or generated mannequin only if core flow is stable. |
| 5:30–7:00 | Revyl flow checks, physical-device AR/performance checks, fixes. |
| 7:00–8:00 | Freeze scope, rehearse, capture backup recording, final fixes. |

At 1:30, a dressed model must rotate and appear in AR. If it does not, reduce to one outfit and prioritize that result. Do not replace the promised 3D experience with an unlabeled flat-image trick. Full-body Object Capture and new-user generation remain stretch features for tomorrow; retain them in the roadmap and never fake successful capture/generation.

Figma priority: basics/model review, Discover, Explore 3D, native AR entry, fit explanation sheet, Bag/mock checkout, and You/edit measurements. Use existing native controls and one visual system; defer designing every edge case from the full brief.

Credentials: no secrets in chat. Capy uses its account/repository connection; Revyl can use the linked integration or a locally configured CI credential; Convex needs authenticated developer setup and its deployment URL in the app. Deployment tokens stay in development/CI. OpenAI and Whop API keys, plus the Whop webhook secret, belong in backend environment variables. Whop is the selected checkout provider. Use hosted checkout only after verifying a suitable test environment; otherwise retain the clearly labeled local simulation. Timebox checkout work to the existing slot and make no live charges.

Catalog selection should use official US bestseller/ranking pages as a popularity proxy, not claim private sales figures or exact sales ranks. Starting sources checked November 14, 2026:

- lululemon bestsellers: https://shop.lululemon.com/c/bestsellers/n1nskl — includes Align No Line High-Rise Pant 25 inches. Select exact additional variants from the page; do not assume 25 inches is full length for every user.
- UNIQLO men's rankings: https://www.uniqlo.com/us/en/spl/ranking/men — surfaced HEATTECH Ultra Warm T-Shirt and Pleated Relaxed Wide Pants.
- UNIQLO women's rankings: https://www.uniqlo.com/us/en/spl/ranking/women — surfaced HEATTECH Ultra Warm T-Shirt and unisex Wide Sweatpants.
- Arc'teryx men's bestsellers: https://arcteryx.com/us/en/c/mens/best-sellers/wid-dlk87r1l — surfaced Beta Jacket and Atom Hoody.
- Arc'teryx women's bestsellers: https://arcteryx.com/us/en/c/womens/best-sellers/wid-dlk87r1l — surfaced Atom Hoody and Beta SL Jacket.

Start with six product cards across these brands; only claim 3D coverage for prepared garments. Exact SKU, imagery, price, size chart, color and availability must be checked on the selected product page when seeding. Photos and bestseller listings do not establish access to exact garment patterns or inventory APIs.
