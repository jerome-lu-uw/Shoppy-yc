import SwiftUI

struct RootView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        @Bindable var store = store
        TabView(selection: $store.selectedTab) {
            Tab("Discover", systemImage: "sparkle", value: AppTab.discover) {
                NavigationStack {
                    DiscoverScreen()
                }
            }
            Tab("Saved", systemImage: "heart", value: AppTab.saved) {
                NavigationStack {
                    SavedScreen()
                }
            }
            Tab("Bag", systemImage: "bag", value: AppTab.bag) {
                NavigationStack {
                    BagScreen()
                }
            }
            .badge(store.bagCount)
            Tab("You", systemImage: "person", value: AppTab.you) {
                NavigationStack {
                    YouScreen()
                }
            }
        }
    }
}

#Preview {
    RootView()
        .environment(AppStore(persistent: false))
}
