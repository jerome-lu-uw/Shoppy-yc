import SwiftUI

struct BagScreen: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        MessageState(eyebrow: "Bag", title: "Ready for a good find.", message: "Your bag is empty. Explore the demo catalog and add a reviewed size when something feels right.") {
            Button("Discover looks") { store.selectedTab = .discover }
                .buttonStyle(.shoppyPrimary)
        }
    }
}
