import SwiftUI
import UniformTypeIdentifiers
import ShoppyCore

/// Handles the model-choice steps: the route picker, the USDZ review, and the two message states.
/// `finish` runs once a model is settled: the onboarding flow pushes the reveal, the replace sheet closes.
struct ModelStepView: View {
    let step: OnboardingStep
    let draft: OnboardingDraft
    @Binding var path: [OnboardingStep]
    let finish: () -> Void

    var body: some View {
        switch step {
        case .review:
            ReviewUploadScreen(draft: draft, path: $path, finish: finish)
        case .unreadable:
            MessageState(
                eyebrow: "Upload / Needs attention",
                title: "Let\u{2019}s try another model.",
                message: "We couldn\u{2019}t read this file. Shoppy needs a USDZ model. Your demo scan stays available."
            ) {
                Button("Choose another file") { path.removeLast() }
                    .buttonStyle(.shoppyPrimary)
                Button("Use the demo scan") {
                    draft.route = .demo
                    finish()
                }
                .buttonStyle(.shoppySecondary)
            }
            .toolbar(.hidden, for: .navigationBar)
        case .unavailable(let route):
            MessageState(
                eyebrow: route == .scan ? "Scan / Device capability" : "Model / Not available yet",
                title: "Another way to make it yours.",
                message: route == .scan
                    ? "Scanning with iPhone isn\u{2019}t available in this version of Shoppy. You can use the demo scan or upload a USDZ."
                    : "Creating a model from your measurements isn\u{2019}t available yet. Your measurements still drive size suggestions. You can use the demo scan or upload a USDZ."
            ) {
                Button("Use the demo scan") {
                    draft.route = .demo
                    finish()
                }
                .buttonStyle(.shoppyPrimary)
                Button("Upload a 3D model") {
                    draft.route = .upload
                    path.removeLast()
                }
                .buttonStyle(.shoppySecondary)
            }
            .toolbar(.hidden, for: .navigationBar)
        default:
            ChooseModelScreen(draft: draft, path: $path, finish: finish)
        }
    }
}

private struct RouteCard: View {
    let title: String
    let detail: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .font(.title3)
                    .foregroundStyle(Theme.ink)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(Theme.ink)
                    Text(detail)
                        .font(.subheadline)
                        .foregroundStyle(Theme.muted)
                        .multilineTextAlignment(.leading)
                }
            }
            .shoppyCard()
            .overlay {
                RoundedRectangle(cornerRadius: Theme.cardRadius)
                    .stroke(isSelected ? Theme.ink : Theme.line, lineWidth: isSelected ? 2 : 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

struct ChooseModelScreen: View {
    @Bindable var draft: OnboardingDraft
    @Binding var path: [OnboardingStep]
    let finish: () -> Void
    @State private var showsImporter = false

    var body: some View {
        ShoppyScreen(eyebrow: "03 / Your model", title: "Make it yours.", trailing: { ExitButton(title: "Back") }) {
            RouteCard(title: "Use the demo scan", detail: "A bundled, calibrated scan. The demo looks are prepared for it.", isSelected: draft.route == .demo) { draft.route = .demo }
            RouteCard(title: "Upload a 3D model", detail: "Use an existing USDZ file. Looks aren\u{2019}t prepared for uploaded models yet.", isSelected: draft.route == .upload) { draft.route = .upload }
            RouteCard(title: "Scan with iPhone", detail: "Have someone help capture you on a supported iPhone. Not available yet.", isSelected: draft.route == .scan) { draft.route = .scan }
            RouteCard(title: "Create from my measurements", detail: "An estimated shape from supported profile details. Not available yet.", isSelected: draft.route == .create) { draft.route = .create }
        } footer: {
            Button("Continue") {
                switch draft.route {
                case .demo: finish()
                case .upload: showsImporter = true
                case .scan, .create: path.append(.unavailable(draft.route))
                }
            }
            .buttonStyle(.shoppyPrimary)
            Text("A file you pick is copied into Shoppy on this device. Nothing is uploaded.")
                .font(.footnote)
                .foregroundStyle(Theme.muted)
        }
        .usdzImporter(isPresented: $showsImporter, draft: draft, path: $path)
    }
}

extension View {
    /// Presents the Files picker for a USDZ, then pushes the review or the unreadable state.
    func usdzImporter(isPresented: Binding<Bool>, draft: OnboardingDraft, path: Binding<[OnboardingStep]>) -> some View {
        fileImporter(isPresented: isPresented, allowedContentTypes: [.usdz]) { result in
            Task {
                guard let readable = await draft.receive(result) else { return }
                if !readable {
                    path.wrappedValue.append(.unreadable)
                } else if path.wrappedValue.last != .review {
                    path.wrappedValue.append(.review)
                }
            }
        }
    }
}

private struct ReviewUploadScreen: View {
    @Bindable var draft: OnboardingDraft
    @Binding var path: [OnboardingStep]
    let finish: () -> Void
    @Environment(AppStore.self) private var store
    @FocusState private var focus: MeasurementKind?
    @State private var angle: ViewAngle = .front
    @State private var showsImporter = false

    var body: some View {
        ShoppyScreen(eyebrow: "Upload / Review", title: "Make scale make sense.", trailing: { ExitButton(title: "Back") }) {
            RowCard(title: draft.importedName ?? "Your model", value: "Replace") { showsImporter = true }
            ModelPreviewView(modelURL: draft.importedURL, angle: angle, allowsRotation: true)
                .frame(height: 300)
            PillSegmented(options: [(ViewAngle.front, "Front"), (.side, "Side")], selection: $angle)
            VStack(alignment: .leading, spacing: 10) {
                Label("Model readable", systemImage: "checkmark.circle.fill")
                Label("Scale needs confirmation", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(Theme.warn)
            }
            .font(.subheadline.weight(.medium))
            .shoppyCard()
            MeasurementField(kind: .height, label: "Confirm standing height", prompt: "178", text: Binding(get: { draft.texts[.height] ?? "" }, set: { draft.texts[.height] = $0 }), units: draft.units, large: true, focus: $focus)
            Text("A model\u{2019}s file scale may differ from your real height.")
                .font(.subheadline)
                .foregroundStyle(Theme.muted)
            InfoBanner("Demo looks are prepared for the demo scan. If you use this model, we\u{2019}ll continue with the demo scan; your file stays saved on this device.", fill: Theme.warnFill)
        } footer: {
            Button("Use this model") {
                store.updateProfile(draft.profile(from: store.profile, kinds: [.height]))
                draft.usedUpload = true
                finish()
            }
            .buttonStyle(.shoppyPrimary)
            .disabled(draft.check(.height) == .empty || !draft.isValid([.height]))
        }
        .scrollDismissesKeyboard(.interactively)
        .usdzImporter(isPresented: $showsImporter, draft: draft, path: $path)
    }
}
