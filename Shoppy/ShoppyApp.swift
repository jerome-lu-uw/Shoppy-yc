import SwiftUI

@main
struct ShoppyApp: App {
    #if DEBUG
    @State private var store = AppStore.launchStore()
    #else
    @State private var store = AppStore()
    #endif

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .tint(Theme.ink)
        }
    }
}
