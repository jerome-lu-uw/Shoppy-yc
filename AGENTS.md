# Shoppy

Native iOS 26 SwiftUI app built at the YC Consumer Mobile Hackathon (November 15, 2026). Try clothes on a 3D model of yourself, get a suggested size, and run a mock checkout. Stack: SwiftUI + RealityKit, Convex, Revyl.

## Layout

- `Shoppy/`: the app target. The Xcode project uses a file-system synchronized group, so any file added under `Shoppy/` joins the target. Never edit `project.pbxproj` to add a source file.
- `Shoppy/App/`: `AppStore` (single `@Observable` source of truth, injected with `.environment`), service protocols, debug launch arguments.
- `Shoppy/Design/`: `Theme` tokens and shared components (`ShoppyScreen`, `MessageState`, `RowCard`, `PillSegmented`, `InfoBanner`, button styles).
- `Shoppy/Features/<Feature>/`: one folder per feature.
- `Shoppy/Preview3D/`: the dressed-model viewer and AR Quick Look entry.
- `ShoppyCore/`: pure Swift package with domain models, the sizing engine, and the seed catalog. No UI imports.
- `convex/`: Convex backend functions and schema.
- `docs/`: product plan, demo-day plan, and the Figma brief.

## Commands

- Core tests: `cd ShoppyCore && swift test`
- App build: `xcodebuild -project Shoppy.xcodeproj -scheme Shoppy -configuration Debug -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath build CODE_SIGNING_ALLOWED=NO build`
- The built app is `build/Build/Products/Debug-iphonesimulator/Shoppy.app`.
- Screenshot a screen: install the app on a simulator and launch with `-shoppySeed YES -shoppyTab <discover|saved|bag|you> -shoppyRoute <feature-defined>` (see `Shoppy/App/DebugLaunch.swift`).

## Conventions

- Swift 5 language mode, iOS 26 minimum. Use `@Observable`, `NavigationStack`, and native controls. The tab bar is the native `TabView`.
- Colors and metrics come from `Theme`. Screens use `ShoppyScreen` or `MessageState` so margins, titles, and pinned footers match the design frames.
- Views read state from `AppStore` and change it only through its methods.
- Copy rules: the 3D view is a "Style preview", sizing is an "Estimated fit", checkout is a demo with no charge and no shipment. Never claim fit accuracy or a real purchase.
- No secrets in the repository. Backend keys live in Convex environment variables.
- No inline code comments beyond doc comments on shared types.
