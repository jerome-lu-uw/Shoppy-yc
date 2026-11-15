import SwiftUI

struct SavedScreen: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        MessageState(eyebrow: "Saved", title: "Your next favorites live here.", message: "Save a look in Discover to start your shortlist. Saving is a preference, not a purchase.") {
            Button("Discover looks") { store.selectedTab = .discover }
                .buttonStyle(.shoppyPrimary)
        }
    }
}
