import SwiftUI
import ShoppyCore

struct ManageModelScreen: View {
    @Environment(AppStore.self) private var store
    @State private var showsRecheck = false
    @State private var showsReplace = false

    var body: some View {
        ShoppyScreen(eyebrow: "Your model", title: "A model of you.", trailing: { ExitButton(title: "Back") }) {
            ModelPreviewView(assetName: nil)
                .frame(height: 250)
            VStack(alignment: .leading, spacing: 12) {
                Text("Demo scan")
                    .font(.headline)
                    .foregroundStyle(Theme.ink)
                detail("Source", "Bundled demo scan")
                detail("Confirmed height", store.profile.value(.height).map { Units.format($0, kind: .height, units: store.profile.units) } ?? "Not set")
                detail("Status", "Ready")
                Text("The demo looks are prepared for this scan. Style previews only; sizing is an estimated fit.")
                    .font(.footnote)
                    .foregroundStyle(Theme.muted)
            }
            .shoppyCard()
        } footer: {
            Button("Recheck scale") { showsRecheck = true }
                .buttonStyle(.shoppyPrimary)
            Button("Replace model") { showsReplace = true }
                .buttonStyle(.shoppySecondary)
        }
        .sheet(isPresented: $showsRecheck) {
            EditMeasurementsScreen(focus: .height, doneTitle: "Back to model")
        }
        .sheet(isPresented: $showsReplace) {
            ReplaceModelSheet()
        }
    }

    private func detail(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title).foregroundStyle(Theme.muted)
            Spacer()
            Text(value).fontWeight(.medium).foregroundStyle(Theme.ink)
        }
        .font(.subheadline)
    }
}

/// The model routes from onboarding, reopened from Manage model.
private struct ReplaceModelSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var draft: OnboardingDraft?
    @State private var path: [OnboardingStep] = []

    var body: some View {
        if let draft {
            NavigationStack(path: $path) {
                ChooseModelScreen(draft: draft, path: $path) { dismiss() }
                    .navigationDestination(for: OnboardingStep.self) { step in
                        ModelStepView(step: step, draft: draft, path: $path) { dismiss() }
                    }
            }
        } else {
            Color.clear.task { draft = OnboardingDraft(profile: store.profile) }
        }
    }
}

#Preview {
    NavigationStack { ManageModelScreen() }
        .environment(AppStore(persistent: false))
}
