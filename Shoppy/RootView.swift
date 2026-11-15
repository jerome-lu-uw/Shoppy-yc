import SwiftUI

struct RootView: View {
    @Environment(AppStore.self) private var store
    @State private var forcesOnboarding: Bool

    init() {
        #if DEBUG
        _forcesOnboarding = State(initialValue: DebugLaunch.route?.hasPrefix("onboarding") == true)
        #else
        _forcesOnboarding = State(initialValue: false)
        #endif
    }

    var body: some View {
        @Bindable var store = store
        if store.hasOnboarded && !forcesOnboarding {
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
        } else {
            OnboardingFlow { forcesOnboarding = false }
        }
    }
}

#Preview {
    RootView()
        .environment(AppStore(persistent: false))
}
