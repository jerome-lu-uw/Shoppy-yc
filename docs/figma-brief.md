# Shoppy — Figma AI design brief

Deadline update: for the November 15 nine-hour build, prioritize the core screens identified in [the demo-day plan](demo-day-plan.md). The full 22-screen set is the broader design roadmap; capture and generation are stretch implementation paths for tomorrow.

This is a design specification for a polished native iPhone demo, not an implementation. The confirmed direction is a multi-gender catalog, approximate interactive 3D clothing layered over a user model, optional floor placement through Apple’s USDZ Quick Look experience, measurement-based size suggestions, and mock checkout. Accurate cloth physics is outside this demo’s scope. The final catalog, generation provider, and sizing-validation thresholds remain product decisions.

The user’s reference scan was captured with Apple ObjectCapture while wearing a short-sleeve top and shorts. Their actual height is 186 cm; the inspected model’s apparent height was about 179.6 cm, so scale confirmation is required. These are project reference facts, not a reason to display private body measurements in shared mockups. Long-sleeve tops and long pants should visually cover the captured outfit where possible. Keep the original surface and allow region masking if it would otherwise protrude; do not imply that the scan contains an unclothed body or guarantees underlying measurements.

**Except for Jerome’s reference facts above, all example brands, product names, prices, inventory, body dimensions, garment measurements, fit assessments, delivery dates, and order numbers in this document are fictional placeholders.** Do not imply that a named retailer has integrated with Shoppy. Retailer photography and logos will be supplied later with appropriate usage rights.

Figma should show static front, side, and back renders and prototype transitions that represent a future interactive 3D viewer. Figma mockups do not generate a working avatar, garment simulation, or functioning 3D try-on engine. Use a neutral, fully clothed placeholder avatar until approved renders of the supplied USDZ are available.

## Copy-paste master prompt

```text
Design a polished native iPhone consumer app called Shoppy. It helps people discover clothing by seeing a personal 3D avatar in different outfits, saving or passing on items, and adding a suggested size to a shopping bag. Create an editable Figma design system and 22 high-fidelity screen/state frames using the screen briefs below. These are design mockups with fictional catalog content, not working integrations.

Product direction:
- Make the app feel like a calm personal fitting room and a beautifully edited fashion catalog.
- Lead with the avatar and outfit. Keep navigation and purchase actions obvious and restrained.
- Use a small multi-gender catalog with long-sleeve tops and full-length pants. Show a range of body shapes and appearances. Let people choose Women, Men, All, or individual garment categories as shopping preferences independent of their body shape or gender identity.
- Call the visual output “Style preview” and the sizing guidance “Estimated fit.” Do not claim perfect fit, accurate fabric draping, or a real purchase. Label generated mannequins as estimates; reserve “scan” for an actually captured model.
- Height and weight are the quick-start inputs. Additional measurements improve the sizing information. Allow Create from measurements, Upload USDZ, and Scan with iPhone routes. The scan route uses Apple ObjectCapture where device capability supports it and gives another person instructions to help capture the user.
- Layer demo clothes over the captured model. A source scan may already include a short-sleeve shirt and shorts; longer garments can cover that surface, with region masking where necessary. Do not promise cloth physics or automatic recovery of the body underneath.
- Include “View in your space” to open the dressed USDZ in an Apple Quick Look-style AR experience with floor placement. Keep this secondary to the discovery flow.
- Automatically suggest a size, display it clearly, and allow review or editing. Never hide the actual size being ordered.
- Checkout is explicitly a demo: “Demo checkout — no charge or real order.”

Visual language:
- Native SwiftUI appearance for iOS 26 and later, with a standard floating Liquid Glass TabView containing Discover, Saved, Bag, and You.
- Use warm ivory (#F6F4EF) and soft white surfaces, near-black (#171717) text, warm gray secondary text, and a tiny restrained lime accent (#D5EF77). Use semantic colors for errors and warnings; do not rely on color alone.
- SF-style system typography with generous whitespace. Approximate type scale: 32 pt primary titles, 22 pt section titles, 17 pt body and primary controls, 15 pt secondary text, and 13 pt captions. Layout must grow with Dynamic Type.
- Main actions use a dark filled capsule or a native prominent button. Use glass for navigation and a few floating controls, not every card or text surface.
- Create a quiet studio backdrop for the avatar: warm off-white, soft contact shadow, neutral illumination, no busy scenery. Render clothing texture and silhouette clearly.
- Use native safe areas, system sheets and pickers, and at least 44 by 44 pt interactive targets. Do not draw a custom device bezel.
- Start with a 393 by 852 pt reference frame, but use Auto Layout and constraints rather than assuming one device size.
- Prepare light, dark, increased-text-size, and reduced-transparency variants for the main discovery and checkout screens.

Navigation and interaction:
- The four tabs are Discover, Saved, Bag, and You. Onboarding is outside the tab shell.
- In the Discover feed, left/right drag passes or saves a clothing card. Include visible Pass, Save, Undo, and Add to Bag actions.
- A clear “Explore 3D” control switches into a separate inspection state. Lock card swiping while this state is active. Show “Drag to rotate,” Front/Side/Back, Reset, and Done. Done returns to the same card and browsing position.
- Use static front/side/back avatar renders and smart-animate transitions to represent 3D. Do not imply that the Figma file contains a working 3D model.
- “Save” is a reversible preference action; “Add to Bag” is a separate purchase-intent action.
- Show product photography thumbnails, brand, product name, price, selected color, and suggested size. Keep detailed measurements in a fit sheet.
- Profile measurement edits update sizing information and create a changed-fit state: affected recommendations refresh and existing bag recommendations need review before checkout. Do not show an imported scan changing body shape. A confirmed height can rescale its working copy; body-shape changes require a replacement scan. A generated avatar can regenerate only from inputs supported by its provider.
- Shared outfit cards exclude height, weight, body measurements, fit confidence, account information, and uploaded model files by default.

Create these 22 frames, with component variants for the error/loading/empty states described in their briefs:
01 Welcome
02 Your basics
03 Add measurements
04 Choose your avatar
05 Import and calibrate USDZ
06 Preparing your avatar
07 Avatar reveal
08 Discover
09 Explore 3D
10 Discovery filters
11 Product detail
12 Why this size
13 Saved
14 Bag
15 Demo checkout
16 Demo order result
17 You
18 Edit measurements
19 Manage your model
20 Share preview
21 Scan with iPhone
22 View in your space

Use fictional brand “Northline,” product “Transit Long-Sleeve,” price “$68,” color “Ink,” and suggested size “M” for one example. Use fictional brand “Fieldform,” product “Everyday Straight Pant,” price “$92,” color “Stone,” and suggested size “32 / Regular” for a second. Label the Figma page and catalog components “Fictional demo content.” These figures are placeholders, not verified retail data.

Create reusable components, accessible control labels, loading/error/empty variants, and a clickable prototype for generated-avatar onboarding, USDZ onboarding, supported-device scanning, discovery-to-checkout, AR floor placement, editing measurements with bag revalidation, and sharing an outfit. Use the detailed screen briefs below as the source of truth.
```

## Screen and state briefs

### 01 — Welcome

**Purpose:** Explain the benefit in one glance and offer an easy start.

Use a large editorial image of a fully clothed avatar in the center, with two small alternate-outfit silhouettes behind it. Place a small Shoppy wordmark at the top and the headline “See your next fit.” below the hero. Supporting copy: “Explore clothes on a model of you.” Use “Get started” as the primary button and a quieter “I already have an account” link. Authentication can be represented by a native sign-in sheet later; do not invent account-provider integrations here.

Keep the screen free of a bottom tab bar. Show the product as a try-on and shopping experience, with no onboarding carousel, social feed, permission dialog, or subscription offer. A small secondary note can read “Style previews. Sizing estimates.” Use inclusive avatar examples across the design set rather than making every screen show the same gender presentation.

### 02 — Your basics

**Purpose:** Make the first input step short while setting honest expectations.

Show “Let’s get your proportions.” with a compact step indicator. Present a Metric / Imperial segmented control and clearly labeled height and weight inputs. Use locale-aware units and a numeric keyboard state. Fictional populated example: 178 cm and 75 kg. Include “You can update these later.” and a primary Continue button anchored above the keyboard or safe area.

Add one quiet explanation: “Height and weight create a starting shape. A few measurements can improve size suggestions.” Do not show a precision score or call the output an accurate body scan. Create empty, populated, invalid-value, and keyboard-visible variants. Changing units must preserve the represented values.

An optional “What would you like to shop?” row can offer Women / Men / All and garment-category choices. Describe this as a shopping preference. Do not use it to assign a body template, infer identity, or populate provider demographic fields.

### 03 — Add measurements

**Purpose:** Offer better sizing information without overwhelming quick-start users.

Use a simple body diagram with selectable chest, waist, hips, inseam, and sleeve locations. Below it, show measurement rows with a value, unit, and “How to measure” action. A compact fit-preference control offers Close / Regular / Relaxed with Regular initially selected. Keep the language about clothing preference neutral.

Primary action: “Save measurements.” Secondary action: “Skip for now.” Supporting copy: “Optional now. We’ll ask for missing measurements when they matter.” A help sheet explains one measurement at a time with a diagram and plain-language instruction; do not put all measuring instructions on the main screen.

Include rows with “Not provided” and a warning for an implausible value without labeling the person’s body as wrong. Distinguish entered measurements from estimates. Age or gender inputs should appear only if the selected avatar provider actually requires them; if a future Bodygram integration requires these fields, add a conditional explanation of the purpose and never infer or silently prefill them.

### 04 — Choose your avatar

**Purpose:** Make generated, uploaded, and newly captured models understandable.

Title: “Make it yours.” Show three selectable cards: “Create from my measurements” with a neutral mannequin illustration, “Upload a 3D model” with a file-and-avatar illustration, and “Scan with iPhone” with a camera-and-person illustration. Describe the first as “An estimated body shape from supported profile details,” the second as “Use an existing USDZ file,” and the third as “Have someone help capture you on a supported iPhone.” Keep the selected card state subtle and provide one Continue action. If a provider only accepts basic statistics, explain that other entered dimensions help sizing but do not necessarily reshape its avatar.

Explain upload and processing choices before a file leaves the phone. Any provider-specific consent belongs next to that provider’s action. Do not advertise a free generation allowance, processing time, or accuracy guarantee until confirmed. The generated route uses available measurements from earlier screens; the upload route opens the native Files picker and proceeds to frame 05; the scan route proceeds to frame 21. Show an explanatory unavailable state for scanning when the runtime capability check fails, with Create and Upload still available.

### 05 — Import and calibrate USDZ

**Purpose:** Verify that the imported asset can be displayed and scaled meaningfully.

Show a file card with a fictional example filename, size, and Replace action. Place the imported model in a studio preview with front/side controls. Display checks for “Model readable,” “Textures available,” “Upright orientation,” and “Scale needs confirmation.” Use clear status text with icons rather than an unexplained technical checklist.

Ask “Confirm your standing height” and reuse the height input. Show a simple vertical guide from floor to head, plus “Rotate upright” and “Reset view” controls if needed. Explain: “A model’s file scale may differ from your real height.” Show “This scan includes existing clothing” when confirmed, followed by “New garments will be layered over your scan.” A short help note can explain that longer tops and pants work best for this demo. Do not suggest that clothing can always be removed automatically. This screen also reviews newly captured scans after reconstruction; change the title to “Review your scan” in that variant.

Primary action: “Use this model.” Variants: uploading, unreadable file, unsupported file, missing texture, uncertain scale, and a recoverable “Create an estimated avatar instead” option. Avoid presenting a plausible-looking rendered model as proof of reliable body measurements.

### 06 — Preparing your avatar

**Purpose:** Make an asynchronous process understandable and recoverable.

Use a large neutral silhouette and a restrained progress indicator. Show real process states conceptually: “Preparing your model,” “Checking proportions,” and “Getting your first looks ready.” Use an indeterminate indicator unless actual job progress is available. Avoid fabricated percentages or countdowns.

Keep a “Continue browsing demo looks” secondary option if the product supports it, and a visible Cancel action. A failure variant reads “We couldn’t finish your model” with Retry and Choose another method. A quota/provider-unavailable variant offers a plain explanation and an existing-model or approximate-avatar fallback without promising that fallback is equivalent. A resumed state should show that the previous job continues rather than restarting silently.

### 07 — Avatar reveal

**Purpose:** Give users a satisfying first result and a chance to correct it.

Show the avatar nearly full height in neutral base clothing. Title: “Your starting point.” Add a small “Estimated avatar” or “Imported model” label that reflects the actual route. Present a short sentence such as “Check your proportions before trying your first looks.” Avoid appearance ratings or body-shape judgments.

Provide Front / Side / Back controls, an “Adjust measurements” action, and the primary “Find my first look.” The preview can use static camera renders in Figma. If scale remains uncertain, display a concise note and a “Confirm height” action. Do not offer purchase sizing as high confidence merely because avatar creation succeeded.

### 08 — Discover

**Purpose:** Deliver the main one-card-at-a-time shopping loop.

At the top, place a small Shoppy wordmark, a concise category label such as “For you,” and a filter button. The avatar occupies most of the content area in a calm studio scene. Add a small “Style preview” label and an “Explore 3D” capsule at a clear, reachable edge of the viewer. A stock-photo thumbnail provides a direct reference to the actual article.

Below the avatar, show fictional brand Northline, “Transit Long-Sleeve,” $68, color Ink, and “Suggested M · Estimated fit.” Make the size row tappable. Include compact Pass and Save buttons, a smaller Undo control, and a prominent “Add to Bag” action. Use the standard floating tabs: Discover, Saved, Bag with count, You. Keep the primary CTA above the tab bar with enough separation to avoid accidental taps.

A left drag shows a restrained “Pass” overlay; a right drag shows “Saved.” Passing or saving advances to the next card. Adding to Bag gives a small confirmation and keeps the current card available. Variants: next-item loading, image-only fallback when 3D is unavailable, offline cached preview, empty filtered feed, saved state, out-of-stock suggested size, and “More measurements needed.” No stock or confidence number is invented.

### 09 — Explore 3D

**Purpose:** Let users inspect an outfit without accidental browsing actions.

Use the same avatar, lighting, and outfit as the active Discover card. Clearly label the state “Explore 3D.” Enlarge the viewer and show “Drag to rotate” once, plus Front / Side / Back camera presets, Reset, and Done. Allow a zoom representation if useful. Lock feed-card swipes entirely while this state is active; do not show Pass/Save swipe overlays. Add a secondary “View in your space” action leading to frame 22 once a dressed USDZ is ready.

Retain a compact bottom summary with the product name, price, selected size, and Add to Bag. Keep “Style preview” visible in an unobtrusive caption. Done returns to the exact same Discover card. In Figma, connect front/side/back rendered variants and annotate them as stand-ins for future RealityKit camera controls.

### 10 — Discovery filters

**Purpose:** Narrow the catalog while keeping discovery playful.

Present a native medium-to-large sheet with a grabber, title “Your edit,” Reset, and Close. Include compact sections for shopping collection (Women / Men / All), garment categories (for example Tops / Pants), brands, color, price range, and preferred fit. Allow multiple category selections. Shopping choices are independent of body measurements and gender identity. Selected chips must have a clear text or icon change, not color alone. Show an optional “Only show items with enough sizing data” toggle with a short explanation.

Use “Show looks” as the primary action. Show a result count only if it comes from the catalog. For a zero-result state, offer “Clear a filter.” Do not make a retailer filter look like an endorsement or confirmed partnership. The sheet remembers choices when reopened.

### 11 — Product detail

**Purpose:** Give users enough garment information to decide without abandoning their avatar.

Open from the product name or stock thumbnail. At the top, offer “On you” and “Product photos” as clearly labeled views. The first uses the avatar render; the second uses a carousel of fictional product images. Follow with brand, product name, price, color swatches with text labels, available variants, and a visible size row: “Suggested M” with Change.

Use concise sections for material, cut, care, garment measurements, and the source/date of product information. Include “Why this size?” and a short “Preview is an approximation” line. A sticky Add to Bag button includes the selected size. Show unavailable-size and stale-price variants. If garment dimensions are absent, say so and downgrade the fit explanation; do not substitute a general body size chart without labeling it.

### 12 — Why this size

**Purpose:** Make automatic sizing understandable, reviewable, and honest.

Use a native sheet titled “Why we suggested M.” Show a summary such as “Room through the chest; regular sleeve length” only as fictional demonstration copy. Add an “Estimated fit” badge and concise confidence language such as “More certain with your entered chest measurement” or “Limited data — add your inseam.” Avoid unvalidated percentages.

Show a compact comparison with labeled data sources. Fictional example: “Your chest: 98 cm — entered by you” and “Garment chest: 108 cm — product measurement,” followed by “10 cm of room around the chest.” Identify circumference versus flat width and preserve units. Add a simple visual of the measured garment area instead of a clinical heat map. Fit preference appears as Regular with an Edit action.

Provide “Keep M,” “Choose another size,” and “Improve my measurements.” A low-information variant should explicitly say that the app cannot make a confident recommendation and allow a reviewed choice before adding to Bag. This sheet is the place for nuance; the discovery card remains minimal.

### 13 — Saved

**Purpose:** Turn liking into a useful shortlist.

Show a two-column grid of saved looks using small avatar renders or product photographs with consistent crops. Each tile includes brand, product name, price, and saved indicator. Use a simple Tops / Pants / All filter. Tapping opens the product detail at the saved item; a contextual action removes it or adds it to Bag with its reviewed variant.

The empty state reads “Your next favorites live here” with “Discover looks.” If measurements change, show a quiet “Fit suggestions are updating” banner and a pending state on affected cards. For items no longer available, retain the saved tile with an explicit unavailable label and allow removal. Avoid a large social follower system in this first version.

### 14 — Bag

**Purpose:** Review exact items and sizes before starting payment.

Use a clean list of product rows with image, brand, product, color, selected size, quantity, price, and Remove. The size is always visible and editable even when automatically suggested. Add “Suggested for you” as a secondary note, not as a replacement for the variant label. Show an order summary with subtotal and clearly provisional shipping/tax labels.

Primary action: “Continue to demo checkout.” A subtle banner states “Demo bag — no real purchase.” Empty state: “Your bag is ready for a good find” plus Discover. If profile measurements changed, show “Your measurements changed. Review these sizes.” affected rows receive a Review size action and checkout remains unavailable until reviewed. Also include stock-changed, price-changed, and offline-recheck states with specific next actions.

### 15 — Demo checkout

**Purpose:** Rehearse the complete buying experience without suggesting a real charge or shipment.

Title: “Demo checkout.” Put “No charge or real order” immediately below it. Use native form sections for fictional shipping address, delivery option, and order summary consistent with the Bag. Show a “Continue to Whop” action leading to a hosted checkout representation only for a verified test configuration. Otherwise use a clearly labeled “Simulate checkout” action. Do not collect real payment credentials in the Figma prototype. Include opening checkout, returning to Shoppy, and waiting for server confirmation states; returning alone does not mean payment succeeded.

Use “Place demo order” as the final action. Show the exact demo total and a clear explanation that fulfillment is simulated. Include hosted-checkout opened, processing, canceled, declined, and connection-failure variants. Errors preserve the bag and address. A retry must not visually imply that a second order has already been created. Use a generic wallet placeholder unless Apple Pay is actually configured in the eventual integration.

### 16 — Demo order result

**Purpose:** Confirm the outcome while keeping simulated fulfillment explicit.

Success variant: a restrained checkmark animation, “Demo order placed,” and “No payment was taken and no items will be shipped.” Show a fictional order number, the selected products/sizes, and a timeline labeled “Simulated status”: Confirmed → Preparing → Shipped. Use “Keep discovering” and “View demo order.” A secondary “Share this look” can open frame 20.

Failure variant: “Your demo payment didn’t complete,” a short recoverable reason, Retry payment, and Return to Bag. Avoid celebratory success treatment while the payment outcome is pending. A pending variant says “Checking your payment result” and provides a safe return path without duplicating checkout.

### 17 — You

**Purpose:** Give the user clear ownership of their avatar, sizing, and saved account settings.

Use a compact avatar portrait or half-body render at the top, a display name placeholder, and “Your model” with its source label. Below, show a concise measurements summary with unit preference and a visible “Edit measurements” action. Include “Manage model,” “Fit preference,” “Demo orders,” “Privacy and data,” and account settings as native list rows.

The main screen should feel personal and useful, not like a health dashboard. Do not show BMI, body ratings, weight goals, or fabricated analytics. Provide a guest-state variant with an optional save-account action. Use the native You tab selection and keep the same visual language as the shopping screens.

### 18 — Edit measurements

**Purpose:** Update sizing safely without concealing the effect on saved recommendations.

Open a native editing screen with Cancel and “Update size suggestions.” Show height, weight, chest, waist, hips, inseam, sleeve, and unit preference. Each measurement has its source: entered, imported estimate, or missing. Include simple measurement help and fit preference. Keep the existing saved profile unchanged until the user saves.

Before saving, display concise impact copy: “We’ll update your size suggestions. Items already in your bag will need a size review.” After saving, show a brief updating state and a success message with “Review bag” if applicable. Cancel returns to the original values. Include validation, offline save pending, and no-change states. Do not silently keep old fit confidence after the body profile changes.

Make visual model changes a separate, source-aware action. For a generated avatar, offer “Regenerate avatar” only when supported generation inputs changed, and state which inputs the selected provider uses. For example, do not imply that a basic Bodygram endpoint accepts arbitrary chest, waist, or inseam constraints. For an imported or captured model, display “Your scan keeps its captured shape. Rescan to change your model.” A confirmed height may offer “Recalibrate model scale,” which changes the working copy’s scale rather than recovering body shape. A failed regeneration retains the last usable model and the newly saved sizing measurements, with their different update states made clear.

### 19 — Manage your model

**Purpose:** Explain what is stored and allow replacement or removal.

Show the active model as a preview with source (Generated, Uploaded, or Captured), creation/update date, confirmed height, and processing status. Provide “Replace model,” “Recheck scale,” and “View original” when supported. Replace model opens the existing route choice from frame 04. Keep a previous usable model available until replacement succeeds.

Under a Privacy and data section, describe the app’s intended storage and processing in concise placeholder copy that must be finalized with implementation. Provide “Delete model” with a native confirmation explaining the specific consequence: the personalized preview becomes unavailable until a new model is created; saved products can remain. Do not claim local-only storage, deletion from a third-party provider, or encryption properties that have not been implemented and verified.

### 20 — Share preview

**Purpose:** Create an optional social loop around an outfit, with deliberate privacy choices.

Show an export preview in a clean portrait card: outfit render, product names, a small Shoppy wordmark, and “Style preview.” The default card excludes height, weight, body measurements, fit confidence, account name, address, order information, and downloadable model files. Use a neutral crop or non-identifying avatar representation by default, with explicit control before including a recognizable face.

Offer background style and front/side view choices, followed by “Share look” using the native share-sheet concept. A future deep link can open the public product/outfit selection for recipients to try on their own avatar; it must not grant access to the sender’s private model. Do not pre-check contact invitations or auto-post. Include a canceled share state and an export-failed state with Retry. Add a small note outside the export artwork: “Only the preview shown here will be shared.”

### 21 — Scan with iPhone

**Purpose:** Guide a supported-device ObjectCapture flow that produces a reviewable scan.

Create a preparation state, a capture state, and a completion/reconstruction state using one reusable screen family. Preparation reads “Ask someone to help scan you.” Use simple illustrations: the person being scanned holds still, the helper moves around them, the whole body stays visible, and the area is well lit with space to move. Explain that the scan records the clothing currently worn. For this demo, fitted short sleeves and shorts make it easier to layer long-sleeve tops and long pants later. Provide alternatives for anyone uncomfortable with this capture setup.

Check device capture/reconstruction capability before promising the feature. Unsupported-device copy: “Scanning isn’t available on this device. You can upload a USDZ or create an estimated avatar.” Camera permission should appear only after the user chooses Start scan; a denied-permission variant offers Settings and the alternative routes.

In capture mode, use a large live-camera region, simple coverage guidance, a visible Cancel action, and state-specific hints such as “Keep the full body in view” or “Move slowly around the person.” Use the actual ObjectCapture guidance in implementation rather than inventing a fixed photo count. Avoid face-recognition boxes, medical imagery, or a fake body-accuracy score. Include interrupted capture, insufficient coverage, motion detected, and retry states.

After capture, show “Building your scan” and then route to frame 05’s review variant. Let the user inspect front/side/back, confirm upright orientation, and calibrate standing height before proceeding to the avatar reveal. Do not treat successful reconstruction as proof that body dimensions underneath the clothing are known.

### 22 — View in your space

**Purpose:** Place the dressed model on the ground through the familiar native USDZ Quick Look AR flow.

Represent this as a system-owned presentation reached from Explore 3D or Product detail. The underlying Shoppy action reads “View in your space.” Show a native-style Quick Look preview, its AR/Object modes where available, and the dressed avatar anchored to a detected floor. Keep system-owned controls recognizable; do not redesign the native AR UI as a branded custom camera app.

Include three conceptual variants: preparing the dressed USDZ, finding a surface, and model placed. Keep proportions calibrated before export. A help note before opening can say “Point your camera toward an open area of floor.” Include permission-denied, unsupported-AR, failed-export, and failed-placement states with a return to the regular 3D viewer. Do not imply that Figma implements plane detection or that the system guarantees precise real-world scale.

Closing returns to the same item in Explore 3D or Product detail. No purchase happens inside the AR scene. The avatar remains fully clothed, with the selected demo garments layered over the captured source model. The app’s “Share look” action exports the image described in frame 20. Account separately for native Quick Look’s system sharing, which may export the dressed USDZ containing the personal model; do not label that system action as image-only sharing. Review the actual system UI before finalizing this surface.

## Reusable component checklist

- Native four-tab shell: Discover, Saved, Bag with badge, You; selected/unselected and accessibility variants.
- Primary, secondary, destructive, icon, and loading buttons with minimum 44 pt targets and explicit accessible names.
- Avatar studio viewport: front/side/back, loading, missing asset, image fallback, source label, and Style preview caption.
- Discover card: default, pass drag, save drag, saved, loading, unavailable, low-sizing-information, and offline.
- Explore 3D toolbar: camera presets, Reset, Done, gesture hint; card swipe disabled in this mode.
- Product summary row: brand, product, price, color, size, product photograph, availability.
- Suggested-size chip: estimated, user-overridden, insufficient information, pending recalculation, and needs review.
- Measurement input: empty, entered, estimated, invalid, disabled, and unit-converted; use source labels.
- Measurement help diagram and one-measurement help sheet.
- Model source choice card and upload status row.
- Scan capability, preparation, capture guidance, reconstruction, and scan-review states.
- View in your space entry control and native Quick Look presentation placeholder with floor-placement states.
- Native sheet shell with grabber, title, Close/Done, and safe-area-aware sticky action.
- Filter chip, color swatch with text label, category selector, and fit-preference selector.
- Bag item with quantity, editable size, remove, revalidation warning, and unavailable variant.
- Order summary and clearly labeled demo-payment status components.
- Empty, loading, error, retry, pending, offline, and success states with specific next actions.
- Shareable outfit card with no personal measurements or hidden private data in the default export.

## Prototype paths

1. **Generated-avatar onboarding:** 01 → 02 → 03 → 04 (Create) → 06 → 07 → 08. Branch from 06 to Retry and back to 04. If provider-required demographic fields are added later, insert them only on the selected provider’s branch.
2. **USDZ onboarding:** 01 → 02 → 03 → 04 (Upload) → native Files picker representation → 05 → 06 → 07 → 08. Include failed import, replacement file, and uncertain-scale branches.
3. **Scan onboarding:** 01 → 02 → 03 → 04 (Scan) → 21 preparation/capture/reconstruction → 05 scan review and height calibration → 07 → 08. Include unsupported device, permission denial, interrupted capture, and reconstruction retry branches.
4. **Discovery and inspection:** 08 → right swipe Save → next card; Undo returns to previous card. 08 → 09 → Front/Side/Back → Done → same 08 card. Confirm that card swipes are inactive in 09.
5. **AR floor placement:** 09 or 11 → 22 export/preparing → native Quick Look AR → floor placement → close → same product and selected variant. Include an AR-unavailable return to the Object/3D preview.
6. **Fit-informed shopping:** 08 → 11 → 12 → Keep size or Choose another → 11 → Add to Bag → 14. The chosen variant stays consistent across every screen.
7. **Demo checkout:** 14 → 15 → processing → 16 success. Separate branches cover cancel back to 14, decline with retry, and pending-result recovery.
8. **Profile update:** 17 → 18 → Save → updating → 17. Navigate to 14 and show changed-fit rows requiring review via 12 before allowing 15.
9. **Model replacement:** 17 → 19 → Replace → 04 → 05, 06, or 21 → 07. Failed replacement returns to 19 with the previous usable model retained.
10. **Sharing:** 08, 11, or 16 → 20 → export preview → native share-sheet representation. Cancel returns without posting or inviting anyone.
11. **Discovery controls:** 08 → 10 → Apply → filtered 08; zero-result state → Clear filter. 13 → product detail → Add to Bag; empty 13 → 08.

## Design review criteria

The first useful outfit should be reachable with a short onboarding path. Optional measurement collection must remain discoverable when fit data is insufficient. A user should be able to tell what is a style approximation, what size is selected, why it was suggested, and whether checkout is simulated without opening settings.

Check the Discover and Explore 3D states side by side: the gesture mode must be unmistakable. Check that the avatar, primary purchase action, and bottom navigation do not overlap at large text sizes. Verify light/dark contrast, reduced-transparency surfaces, reduced-motion transitions, accessible labels, and explicit alternatives to swipes.

Keep fictitious catalog and measurement data labeled in the Figma file. Before implementation, replace placeholder claims about model processing, data storage, delivery, retailer stock, sizing confidence, and provider requirements with verified product behavior.

Native Liquid Glass and RealityView references for later implementation: [Apple’s Liquid Glass adoption guidance](https://developer.apple.com/documentation/technologyoverviews/adopting-liquid-glass) and [RealityView documentation](https://developer.apple.com/documentation/realitykit/realityview). This brief uses iOS 26 as the minimum deployment target, not as a claim about the latest iOS release.
