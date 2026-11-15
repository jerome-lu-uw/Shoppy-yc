import SwiftUI
import ShoppyCore

/// Text button in a screen's top corner, for example "Back" or "Cancel". Dismisses the pushed screen or sheet.
struct ExitButton: View {
    let title: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Button(title) { dismiss() }
            .foregroundStyle(Theme.ink)
            .frame(minHeight: 44)
    }
}

/// A card with a label, a number field, a unit, and the "Check this value" error.
struct MeasurementField: View {
    let kind: MeasurementKind
    let label: String
    var prompt = "Optional"
    @Binding var text: String
    let units: UnitSystem
    var large = false
    var focus: FocusState<MeasurementKind?>.Binding?

    private var isInvalid: Bool {
        MeasurementRules.check(text, kind: kind, units: units) == .invalid
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(large ? .subheadline : .body)
                .foregroundStyle(large ? Theme.muted : Theme.ink)
            HStack {
                field
                    .keyboardType(.decimalPad)
                    .font(large ? .title.weight(.medium) : .body.weight(.medium))
                    .multilineTextAlignment(.leading)
                Text(Units.unitLabel(kind: kind, units: units))
                    .font(large ? .title2 : .body)
                    .foregroundStyle(Theme.muted)
            }
            if isInvalid {
                Text("Check this value")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.error)
                Text(MeasurementRules.hint(kind, units: units))
                    .font(.footnote)
                    .foregroundStyle(Theme.muted)
            }
        }
        .shoppyCard()
        .overlay {
            if isInvalid {
                RoundedRectangle(cornerRadius: Theme.cardRadius).stroke(Theme.error, lineWidth: 1.5)
            }
        }
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private var field: some View {
        if let focus {
            TextField(prompt, text: $text).focused(focus, equals: kind)
        } else {
            TextField(prompt, text: $text)
        }
    }
}

/// Onboarding: Welcome, basics, measurements, model routes, then the reveal. Sets `hasOnboarded` at the end.
struct OnboardingFlow: View {
    @Environment(AppStore.self) private var store
    @State private var path: [OnboardingStep]
    @State private var draft: OnboardingDraft
    var onFinish: () -> Void = {}

    init(onFinish: @escaping () -> Void = {}) {
        self.onFinish = onFinish
        var initialPath: [OnboardingStep] = []
        let draft = OnboardingDraft()
        #if DEBUG
        if let route = DebugLaunch.route, route.hasPrefix("onboarding:") {
            draft.texts = [.height: "178", .weight: "75"]
            switch route.dropFirst("onboarding:".count) {
            case "basics": initialPath = [.basics]
            case "measurements": initialPath = [.basics, .measurements]
            case "model": initialPath = [.basics, .measurements, .model]
            case "review":
                draft.importedName = "my-model.usdz"
                draft.importedURL = URL.applicationSupportDirectory.appending(path: "ImportedModels/my-model.usdz")
                draft.route = .upload
                initialPath = [.basics, .measurements, .model, .review]
            case "unreadable": initialPath = [.basics, .measurements, .model, .unreadable]
            case "unavailable": initialPath = [.basics, .measurements, .model, .unavailable(.scan)]
            case "reveal": initialPath = [.basics, .measurements, .model, .reveal]
            default: break
            }
        }
        #endif
        _path = State(initialValue: initialPath)
        _draft = State(initialValue: draft)
    }

    var body: some View {
        NavigationStack(path: $path) {
            WelcomeScreen { path.append(.basics) }
                .navigationDestination(for: OnboardingStep.self) { step in
                    switch step {
                    case .basics:
                        BasicsScreen(draft: draft) { path.append(.measurements) }
                    case .measurements:
                        MeasurementsStepScreen(draft: draft) { path.append(.model) }
                    case .reveal:
                        RevealScreen(draft: draft) {
                            store.selectedTab = .discover
                            store.hasOnboarded = true
                            onFinish()
                        }
                    case .model, .review, .unreadable, .unavailable:
                        ModelStepView(step: step, draft: draft, path: $path) { path.append(.reveal) }
                    }
                }
        }
    }
}

private struct WelcomeScreen: View {
    let start: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.spacing) {
            Text("shoppy")
                .font(.title.weight(.bold))
                .foregroundStyle(Theme.ink)
            ModelPreviewView(assetName: nil)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.vertical, 8)
            Text("See your next fit.")
                .font(.largeTitle.bold())
                .foregroundStyle(Theme.ink)
                .accessibilityAddTraits(.isHeader)
            Text("Explore clothes on a model of you.")
                .foregroundStyle(Theme.muted)
            Button("Get started", action: start)
                .buttonStyle(.shoppyPrimary)
                .padding(.top, 8)
            Text("Style previews. Sizing estimates.")
                .font(.footnote)
                .foregroundStyle(Theme.muted)
                .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, Theme.margin)
        .padding(.vertical, 12)
        .background(Theme.ivory.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
    }
}

private struct BasicsScreen: View {
    @Bindable var draft: OnboardingDraft
    @Environment(AppStore.self) private var store
    @FocusState private var focus: MeasurementKind?
    let next: () -> Void

    var body: some View {
        ShoppyScreen(eyebrow: "01 / Your profile", title: "Let\u{2019}s get your proportions.", trailing: { ExitButton(title: "Back") }) {
            PillSegmented(options: [(UnitSystem.metric, "Metric"), (.imperial, "Imperial")], selection: Binding(get: { draft.units }, set: draft.setUnits))
            MeasurementField(kind: .height, label: "Height", prompt: draft.units == .metric ? "178" : "70", text: textBinding(.height), units: draft.units, large: true, focus: $focus)
            MeasurementField(kind: .weight, label: "Weight", prompt: draft.units == .metric ? "75" : "165", text: textBinding(.weight), units: draft.units, large: true, focus: $focus)
            VStack(alignment: .leading, spacing: 8) {
                Text("What would you like to shop?")
                    .font(.subheadline)
                    .foregroundStyle(Theme.muted)
                PillSegmented(options: [(ShoppingCollection.women, "Women"), (.men, "Men"), (.all, "All")], selection: $draft.collection)
                Text("A shopping preference only. It doesn\u{2019}t change your model.")
                    .font(.footnote)
                    .foregroundStyle(Theme.muted)
            }
            .padding(.top, 4)
            Text("Height and weight create a starting shape. A few measurements can improve size suggestions. You can update these later.")
                .font(.subheadline)
                .foregroundStyle(Theme.muted)
        } footer: {
            Button("Continue") {
                store.updateProfile(draft.profile(from: store.profile, kinds: [.height, .weight]))
                focus = nil
                next()
            }
            .buttonStyle(.shoppyPrimary)
            .disabled(!draft.isValid([.height, .weight], required: [.height, .weight]))
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private func textBinding(_ kind: MeasurementKind) -> Binding<String> {
        Binding(get: { draft.texts[kind] ?? "" }, set: { draft.texts[kind] = $0 })
    }
}

private struct MeasurementsStepScreen: View {
    @Bindable var draft: OnboardingDraft
    @Environment(AppStore.self) private var store
    @FocusState private var focus: MeasurementKind?
    let next: () -> Void
    private let kinds: [MeasurementKind] = [.chest, .waist, .hips, .inseam, .sleeve]

    var body: some View {
        ShoppyScreen(eyebrow: "02 / Sizing details", title: "A little more you.", trailing: { ExitButton(title: "Back") }) {
            ModelPreviewView(assetName: nil)
                .frame(height: 220)
            ForEach(kinds, id: \.self) { kind in
                MeasurementField(kind: kind, label: kind.displayName, text: Binding(get: { draft.texts[kind] ?? "" }, set: { draft.texts[kind] = $0 }), units: draft.units, focus: $focus)
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("Fit preference")
                    .font(.subheadline)
                    .foregroundStyle(Theme.muted)
                PillSegmented(options: FitPreference.allCases.map { ($0, $0.rawValue.capitalized) }, selection: $draft.fit)
            }
            .padding(.top, 4)
            Text("Optional now. We\u{2019}ll ask for missing measurements when they matter.")
                .font(.subheadline)
                .foregroundStyle(Theme.muted)
        } footer: {
            Button("Save measurements") {
                store.updateProfile(draft.profile(from: store.profile, kinds: kinds))
                focus = nil
                next()
            }
            .buttonStyle(.shoppyPrimary)
            .disabled(!draft.isValid(kinds))
            Button("Skip for now") {
                focus = nil
                next()
            }
            .buttonStyle(.shoppyLink)
        }
        .scrollDismissesKeyboard(.interactively)
    }
}

private struct RevealScreen: View {
    let draft: OnboardingDraft
    let finish: () -> Void
    @State private var angle: ViewAngle = .front
    @State private var showsEditor = false

    var body: some View {
        ShoppyScreen(eyebrow: "Your model", title: "Your starting point.", trailing: { ExitButton(title: "Back") }) {
            ModelPreviewView(assetName: nil, angle: angle, allowsRotation: true)
                .frame(height: 400)
            PillSegmented(options: ViewAngle.allCases.map { ($0, $0.rawValue.capitalized) }, selection: $angle)
            Text("Demo scan \u{00B7} Check your proportions before trying your first looks.")
                .font(.subheadline)
                .foregroundStyle(Theme.muted)
            if draft.usedUpload {
                InfoBanner("Demo looks are prepared for the demo scan, so we\u{2019}re continuing with it. Your uploaded file is saved on this device but isn\u{2019}t wearing any looks.", fill: Theme.warnFill)
            }
        } footer: {
            Button("Find my first look", action: finish)
                .buttonStyle(.shoppyPrimary)
            Button("Adjust measurements") { showsEditor = true }
                .buttonStyle(.shoppyLink)
        }
        .sheet(isPresented: $showsEditor) {
            EditMeasurementsScreen()
        }
    }
}

#Preview {
    OnboardingFlow()
        .environment(AppStore(persistent: false))
}
