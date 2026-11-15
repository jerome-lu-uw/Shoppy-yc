Shoppy — execution plan, November 14, 2026

Schedule update: the confirmed coding window is November 15, 11 AM–8 PM Pacific. See [the nine-hour demo plan](demo-day-plan.md) for tomorrow's reduced scope and priorities. This document retains the broader product roadmap.

This is a planning document. No app, accounts, integrations, purchases, or deployments have been created. The companion Figma brief describes the screens to design before implementation.

Your confirmed direction is a polished, multi-gender demo: users upload a scan, capture one with an iPhone, or generate an estimated avatar; browse clothing on their own model; save items; receive an automatic size suggestion; and complete mock checkout. Clothing should sit over the existing model. “Drop onto the ground” is interpreted as placing the dressed model in a room with Apple AR Quick Look. Live cloth falling, fabric simulation, and real retailer purchasing are later capabilities.

The product promise should be: “See the look on you. Find your suggested size.” A visual clothing overlay and a size recommendation have different evidence and should be explained separately.

1. Establish a small, convincing demo.

Start with approximately 12 curated styles: six long-sleeve tops and six full-length bottoms, spanning women’s, men’s, and unisex catalog categories. These categories describe retailer inventory; users can browse any category. Use a bounded set of prepared size/color variants and clearly identify demo inventory. Begin with one top and one pair of trousers on Jerome’s scan, then expand only after that looks convincing from the front, side, and back.

The first complete loop is: create profile → choose a model source → review/calibrate avatar → see dressed avatar → swipe/save → inspect in 3D → place in the room → add the suggested variant to bag → sandbox payment → simulated order. A second loop edits measurements and updates recommendations.

Build the clothing overlay and AR demonstration before investing in a large feed or retailer integrations. That prototype resolves the largest unknown: whether the available scan and garment assets can create the experience you want.

2. Use the supplied model as the first technical test.

Local structural inspection of `Jerome 3D model.usdz` found:

| Property | Finding | Implication |
| --- | --- | --- |
| Creator metadata | Apple RealityKit Object Capture | Consistent with your capture method. |
| Archive | Approximately 11 MB; one mesh and three texture maps | Suitable starting size for a demo, subject to device profiling. |
| Geometry | 12,501 vertices and 24,999 faces | Rotation does not require a skeleton. |
| Textures | Three 2048 × 2048 maps | Retain appearance while optimizing the combined garment assets. |
| Structure | One baked mesh; no skeleton or blend shapes detected | Existing shirt and shorts are not separate objects that can simply be removed. |
| Coordinates | Y-up; `metersPerUnit = 1` | Preserve these conventions in clothing assets and AR export. |
| Vertical extent | About 1.796 m | Compare with your stated 1.86 m before calibration. This is a mesh bound, not a validated height measurement. |

A uniform preview-scale adjustment would be approximately 1.036, but first inspect pose, feet, hair, and any capture artifacts. Height calibration alone does not validate chest or waist circumference.

Because you wore short sleeves and shorts, long sleeves and trousers can cover much of the original outfit. Prepare a copy of the scan, locate shoulders/hips/elbows/knees, and align separate garment meshes to its pose. Where the old shirt or shorts protrude, use artist-authored region masks or remove covered faces from the display copy. This requires quality checks at the neckline, cuffs, waistband, and hems. It does not reconstruct the body hidden under clothing. Retain the original upload unchanged.

For arbitrary user scans, introduce a suitability check: full body visible, usable pose, adequate limb separation, supported scale, and no severe holes. Offer an estimated mannequin if an upload cannot support a convincing overlay. Do not promise every USDZ can immediately wear every garment.

3. Support three model-source paths.

| Path | Proposed behavior | Limits |
| --- | --- | --- |
| Upload a model | System file picker for USDZ; validate; show preview; confirm height; normalize orientation and ground origin; prepare a display copy. | A USDZ file can contain any object. Validate that it is a usable full-body scan, and handle unsupported scans explicitly. |
| Scan with iPhone | Guided camera capture using `ObjectCaptureSession` and reconstruction using `PhotogrammetrySession` when supported. Review scan before accepting it. | Check hardware support for capture and reconstruction separately. People moving during capture can produce artifacts. |
| Generate an avatar | Create a neutral estimated body from basic stats, then show review and optional measurement refinement. | Height and weight cannot uniquely specify body shape or facial likeness. API trial availability is not a sustainable production free tier. |

Object Capture should be an experimental guided route in the demo. Ask another person to walk around the stationary subject, capture all sides in even lighting, and keep arms slightly separated from the torso with feet apart. Use close-fitting ordinary clothing. Do not require a user to undress. This workflow is an engineering adaptation of object photogrammetry, not a claim that Apple supplies a validated human measurement system. Apple’s guidance emphasizes photographing a consistent object from multiple views. [Apple capture guidance](https://developer.apple.com/documentation/realitykit/capturing-photographs-for-realitykit-object-capture/), [ObjectCaptureSession](https://developer.apple.com/documentation/realitykit/objectcapturesession).

Check `ObjectCaptureSession.isSupported` before creating the capture session, and check `PhotogrammetrySession.isSupported` independently before reconstruction. Show camera permission only when scanning or entering AR. Unsupported devices, denied permission, reconstruction failure, and interrupted sessions must have Upload and Generate exits. Prefer local capture/reconstruction where supported. Do not upload raw capture photos merely to make the demo work. [Capture availability](https://developer.apple.com/documentation/realitykit/objectcapturesession/issupported), [Reconstruction availability](https://developer.apple.com/documentation/realitykit/photogrammetrysession/issupported).

Bodygram is the strongest verified API candidate for an initial evaluation. Its stats route requires height, weight, age, and a provider gender category; photos are optional. Collect additional required inputs explicitly and keep them separate from shopping preferences. Its documented offer is five free API scans at signup, followed by a sales conversation. [Bodygram platform](https://docs.bodygram.com/platform), [API inputs](https://docs.bodygram.com/platform/first-scan).

Bodygram returns an estimated OBJ body mesh without textures/materials. Convert and prepare it for the mobile viewer; do not promise a recognizable face or direct arbitrary chest/waist/inseam controls through its basic endpoint. Store manually supplied measurements independently. Its experimental adjustment endpoint is not a required dependency. [Avatar format](https://docs.bodygram.com/platform/avatar), [Experimental adjustments](https://docs.bodygram.com/platform/future-you).

If ongoing free API usage is essential, evaluate a self-controlled parametric mannequin built from appropriately licensed assets. That saves per-generation vendor fees but still needs development and compute. MakeHuman core assets are CC0, while application code and third-party assets have separate licensing considerations. Generic image-to-3D services do not establish measurement accuracy; Meshy’s current API quickstart requires a paid plan for API keys. [MakeHuman licensing](https://download.makehumancommunity.org/about/license.html), [Meshy API access](https://docs.meshy.ai/en/api/quick-start).

4. Build real garment geometry for the interactive preview.

Retailer photos provide color, surface detail, silhouette references, and merchandising information. They do not provide an exact sewing pattern or fabric simulation. For the demo, use a small library of authored garment templates, refined from permitted product imagery and actual garment measurements. Keep every garment as a separate asset from the body.

The asset pipeline should be:

1. Collect product references and record which measurements describe the garment versus the intended wearer.
2. Author a top or trouser mesh using a suitable template; prepare fabric materials and texture details.
3. Create the selected size geometry. Preserve its intended dimensions instead of enlarging every garment until it appears to fit.
4. Align it to the scan’s pose or the generated mannequin; use controlled deformation and fix visible intersections.
5. Apply body-region masks to hide covered scan surfaces where necessary.
6. Review front, side, back, cuffs, collar, crotch, and hems. Record that the result is a style preview.
7. Export mobile assets and a combined USDZ for AR. Cache by avatar version, garment/variant, and asset-pipeline version.

For the first demo, manually prepared combinations are acceptable, but identify them as curated coverage. General support for newly uploaded bodies requires a separate fitting/landmark pipeline and its own evaluation. Baking clothing placement ahead of time still permits a fully interactive 3D view on the phone.

More realistic draping later requires sewing patterns, fabric properties, and collision handling. Do not make a physics engine part of the initial demo’s critical path. CLO’s documentation explains the role of fabric behavior in simulation. [CLO fabric behavior](https://support.clo3d.com/hc/en-us/articles/115013660747-How-accurate-are-virtual-fabrics).

5. Deliver the Apple-style preview you described.

Use RealityKit inside SwiftUI for the in-app studio view, with a virtual camera and a softly lit background. Prepare a single composite USDZ containing the avatar and selected garment for the system AR viewer. Both views must show the same outfit and scale.

Normalize to meters, place the soles at the ground origin, and test real-world height. Open the cached local composite with `QLPreviewController` and `ARQuickLookPreviewItem`. Set `allowsContentScaling = false` for the life-size preview. Let the system detect a surface and position the model. This is a dressed digital model standing in the room; it is not live clothing tracked onto the person holding the camera. [AR Quick Look integration](https://developer.apple.com/documentation/arkit/previewing-a-model-with-ar-quick-look), [USDZ scale guidance](https://developer.apple.com/videos/play/wwdc2023/10274/), [Scaling control](https://developer.apple.com/documentation/quicklook/arquicklookpreviewitem/allowscontentscaling).

Default Discover gestures should swipe the card left/right. “Explore 3D” enters an explicit mode in which dragging rotates the model and swiping cards is disabled. “Done” returns to the same product. Provide Front, Side, and Back buttons, and explicit Pass/Save buttons so the interaction works without gestures.

6. Make size selection evidence-based and understandable.

Use two independent outputs: an outfit preview and a size recommendation. The visual fit should never be the only source for the chosen size. Profile data should include units, timestamp, source, and verification status for each measurement.

Start with height and weight to reduce friction. Encourage chest/bust, waist, hip, inseam, and sleeve measurements before relying on automatic clothing sizes. Add shoulder width and rise/torso preferences where the category warrants them. Let users choose close, regular, or relaxed fit. Do not invent missing dimensions or infer shopping categories from appearance.

| Product data | Required interpretation |
| --- | --- |
| Brand body-size chart | Map the user’s measurements into the intended wearer range. |
| Actual garment dimensions | Compare garment dimensions with body dimensions and category-specific ease. |
| Flat width | Record the measurement method; convert to circumference only where that interpretation is appropriate. |
| Sleeve length | Distinguish shoulder-to-cuff from center-back-neck-to-cuff. |
| Pants waist | Distinguish relaxed and stretched waist, plus rise position. |
| Lengths | Preserve inseam, garment length, and available short/regular/tall variants. |

UNIQLO is a useful first catalog source because its documentation distinguishes actual product measurements from body dimensions. Arc’teryx says its sizing guides are general body-fit references, and lululemon’s guides also use body measurements. Verify each selected SKU rather than assuming brand-wide data quality. [UNIQLO sizing](https://faq-us.uniqlo.com/articles/en_US/Knowledge/How-can-I-figure-out-my-size/), [Arc’teryx tops](https://arcteryx.com/us/en/help/sizing/mens/tops), [lululemon sizing](https://shop.lululemon.com/help/size-guide/mens).

The initial recommendation engine can be deterministic: normalize units → choose the correct region/product chart → compare key dimensions → account for intended fit/stretch → rank available variants → return the selected variant plus understandable reasons. Keep rules versioned. Missing information should lower confidence or request a measurement. Use “Estimated fit” and explain the evidence; do not display invented precision such as “98% accurate.”

Automatically select the variant when evidence is sufficient. Keep “Why this size?” and “Change” available. When evidence is weak, users can continue browsing and saving, but must confirm a size or supply the missing measurement before checkout. Recheck recommendations after profile changes and never silently replace variants already in the bag.

Measurement edits and model edits have different effects. Update sizing from saved chest/waist/inseam values immediately. Regenerate an estimated avatar when supported provider inputs change; arbitrary measurement-constrained morphing requires a separate body fitter. An imported scan retains its captured body shape until replacement or rescan, although its working copy can be recalibrated for height. Explain this in the editor rather than silently claiming every measurement changes the scan’s geometry.

7. Use Capy, Revyl, and Convex throughout development.

| Layer | Technology | Scope |
| --- | --- | --- |
| Native app | SwiftUI + RealityKit + Quick Look | Onboarding, capture/import, swipe feed, model interaction, AR, bag, profile. |
| App state | Observation, typed navigation, structured concurrency | Explicit screen state, cancellable loading, responsive UI. |
| Backend | Convex TypeScript functions/database/storage | Profiles, catalog, likes, recommendations, processing jobs, cart, orders. |
| iOS backend connection | Official Convex Swift package | Queries, mutations, actions, real-time updates. |
| Engineering | Capy | Implement bounded features, review changes, fix failures. |
| Builds and QA | Revyl | Native builds, simulator workflows, screenshots/recordings, regression tests. |
| 3D preparation | Asset-authoring tools and a bounded external worker | Mesh processing, fitting, conversion, and composite USDZ export. |
| Payments | Whop hosted checkout through Convex | Local simulation until a suitable Whop test environment is verified; no real charges in the demo. |

Capy documents using Revyl runners for native mobile builds; cloud mobile features require Pro or above. Convex documents an official Swift client, including subscriptions. These services can cover the majority of app development and backend work, while the 3D asset work remains a specialized dependency. [Capy cloud phones](https://docs.capy.ai/cloud-phones), [Revyl documentation](https://docs.revyl.com/welcome), [Convex Swift](https://docs.convex.dev/client/swift/overview).

Target iOS 26 and later using the current stable Xcode/Swift toolchain. Use native `TabView` for Discover, Saved, Bag, and You so the system supplies Liquid Glass. Use `@Observable` models and `NavigationStack`; gate newer OS-only APIs. Use standard controls and reserve glass for navigation and floating controls. [Apple Liquid Glass](https://developer.apple.com/documentation/technologyoverviews/adopting-liquid-glass), [SwiftUI model data](https://developer.apple.com/documentation/swiftui/managing-model-data-in-your-app), [RealityView](https://developer.apple.com/documentation/realitykit/realityview).

Keep the architecture small: feature views, domain models, and service boundaries for catalog, avatars, sizing, checkout, and fulfillment. Authentication must be verified for native Swift before selecting a provider; a local guest preview can precede sign-in, while cloud body uploads require authenticated ownership. Do not assume web authentication examples transfer unchanged to iOS.

Suggested Convex data groups are users/profiles; measurement versions; avatars/assets; products/variants/measurement sources; try-on jobs/results; likes; carts/cart items; orders/payments/fulfillment events; and share records. Every private record carries ownership. Each recommendation references the body-data version, product-measurement version, and rules version used to compute it.

The job flow is: iPhone submits intent → Convex mutation saves a job → scheduled action calls the provider/worker → authenticated completion updates status → Swift subscription updates the screen. Use idempotency keys, bounded retries, explicit failure states, and cancellation. Convex actions can call external services; heavy 3D processing belongs outside that runtime. [Convex actions](https://docs.convex.dev/functions/actions).

Keep private body models behind authenticated access. Ordinary reusable file URLs should not be treated as owner-only access control. Use an authenticated file-serving path or suitable private object storage. Delete derived previews and cancel queued jobs when a body model/account is deleted; address provider retention as part of the integration. Do not send scans or body measurements into analytics. [Convex file serving](https://docs.convex.dev/file-storage/serve-files).

8. Implement mock commerce with a future fulfillment boundary.

Use Whop as the checkout provider. Convex validates the cart and selected variants, calculates the authoritative total, creates a pending order, and requests a hosted checkout URL. The iPhone opens that URL and observes order status from Convex. Store Whop credentials only in backend environment variables. Verify webhook signatures, expected amount/currency and order association; deduplicate events before marking an order paid. Returning from checkout is not payment confirmation. Whop documents checkout links and payment APIs; a suitable account-specific test environment still needs verification. Until verified, use an explicitly simulated local checkout adapter and simulated demo orders, without live charges or claims of completed Whop integration. [Whop API guide](https://whop.com/blog/how-to-use-the-whop-api/), [Whop developer platform](https://docs.whop.com/).

After payment, a mock fulfillment adapter creates simulated order and shipment events. Display “Demo checkout — no charge or shipment.” No test payment should trigger a retailer purchase. Clothing purchases are physical goods, for which Apple permits payment methods such as Apple Pay/card entry rather than in-app purchase. [App Review physical goods guidance](https://developer.apple.com/app-store/review/guidelines/#other-purchase-methods).

Real purchasing is a separate release milestone. It requires a verified retailer/partner ordering path, permission to use catalog assets, current inventory and prices, a seller/fulfillment operating model, shipping/tax handling, returns, customer support, and reconciliation when supplier orders fail. A successful Whop payment does not buy an item from a retailer. Do not assume public ordering APIs exist for the named brands. Initially test one real fulfillment partner, not automatic checkout across arbitrary retailer websites.

9. Design sharing into the useful moment.

The first sharing feature is a clean image or short turntable clip of the user’s dressed avatar with a small Shoppy mark. Users explicitly choose to share. Do not publish body measurements or the original 3D scan with the image. Offer the share action after an outfit looks good, not as a prerequisite to browsing. Review native Quick Look’s separate system sharing behavior: it may allow export of the dressed USDZ, so the app must not describe that action as image-only sharing.

A later “Which look?” feature can compare two outfits through a lightweight share link and bring the recipient into their own try-on flow. Test whether this increases activated users rather than optimizing for shares alone. Keep public profiles and a social feed out of the first demo.

Track onboarding completion, time to first dressed preview, successful model preparation, saves per session, bag additions, mock checkout completion, share-to-open conversion, and return visits. Actual fit validation needs garment measurements and wearer feedback, not engagement metrics or screenshots.

10. Execute in milestones with explicit completion criteria.

| Milestone | Work | Completion criteria |
| --- | --- | --- |
| A: Design and data audit | Approve Figma flow; select initial garments; inspect imagery/measurement availability; confirm accounts. | Agreed screens, concrete catalog subset, and known source for each garment’s data. |
| B: 3D feasibility | Calibrate Jerome’s scan; overlay one long-sleeve top and trousers; export composite; open on iPhone. | Same outfit rotates in-app and stands at intended scale in AR, without obvious clipping. |
| C: App foundation | SwiftUI tabs, Convex connection, model-source flow, profile versions, local cache. | User can establish a profile and recover from invalid/failed model input. |
| D: Capture and generation | Object Capture support checks and guided workflow; Bodygram evaluation or fallback mannequin. | All three source paths have honest success/failure states and a usable preview. |
| E: Catalog and recommendation | Expand curated garments across women’s/men’s/unisex options; feed, filters, likes, sizing explanation. | Selected variants are traceable to measurements and users can review or change them. |
| F: Commerce and sharing | Bag, sandbox checkout, simulated fulfillment, share image, profile editing. | Full loop succeeds; failures/retries do not duplicate orders; body updates trigger rechecks. |
| G: QA and presentation | Revyl regression flows, accessibility, physical-device AR/performance, demo recording. | No critical flow blockers; known limitations documented; polished demo runs reliably. |

Planning estimate: approximately 6–8 weeks for a polished curated demo with an experienced iOS/backend engineer plus part-time 3D asset help, assuming prompt decisions and provider access. This is an estimate, not a commitment. Arbitrary-scan fitting and reliable human Object Capture are the largest schedule risks. A convincing single-person/two-garment prototype should come much earlier and determine whether the broader estimate is realistic.

Capy’s current Pro listing starts at $100/month, and its mobile usage has metered costs. Revyl and Convex offer entry/free plans, but do not assume enough free usage for large 3D traffic. Bodygram’s five scans are evaluation access. Budget separately for garment authoring, model processing, storage/egress, and device testing; a free generation API does not make the entire stack free. Recheck account-specific terms before buying a plan. [Capy pricing](https://capy.ai/pricing), [Revyl pricing](https://revyl.com/pricing/), [Convex pricing](https://www.convex.dev/pricing).

11. Validate the behaviors that matter.

Use Swift tests for unit conversion, chart interpretation, variant selection, and state transitions. Use backend tests for ownership, duplicate jobs/payment events, stale profiles, and order reconciliation. Use Revyl to exercise UI flows and capture evidence, then a real iPhone for Object Capture, AR scale, loading performance, and thermal/memory behavior.

Required scenarios include unsupported capture hardware; permission denied; malformed or oversized USDZ; interrupted generation; no network; swipe versus rotation; missing garment dimensions; unavailable recommended size; profile edits while jobs run; retry/cancel/declined payment; repeated add-to-bag taps; account/model deletion; Dynamic Type; VoiceOver; Reduce Motion; and Reduce Transparency.

Treat a responsive cached feed and bounded model memory as performance goals. Prefetch only a small number of upcoming previews, cancel obsolete downloads/jobs, and use still-image placeholders while 3D loads. Do not generate a fresh garment on every swipe.

Before implementation, the remaining decisions are the deadline/budget, existing Capy/Revyl/Convex access, the first concrete product list, and whether the five-scan generation trial is acceptable for the demo. The approved direction already establishes multi-gender scope, overlay-style 3D, Object Capture, AR placement, and mock checkout; those do not need to be re-confirmed.
