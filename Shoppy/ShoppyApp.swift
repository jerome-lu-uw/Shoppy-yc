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
            root
                .environment(store)
                .tint(Theme.ink)
                .task {
                    connectBackend()
                }
        }
    }

    @ViewBuilder private var root: some View {
        #if DEBUG
        if DebugLaunch.route == "preview3d" {
            Preview3DDebugScreen()
        } else {
            RootView()
        }
        #else
        RootView()
        #endif
    }

    private func connectBackend() {
        #if DEBUG
        if DebugLaunch.seedsDemoState { return }
        #endif
        guard store.sync == nil, let url = BackendConfig.deploymentURL else { return }
        let sync = ConvexSync(deploymentURL: url)
        store.sync = sync
        store.checkout = ConvexCheckout(sync: sync)
        sync.start(store: store)
    }
}
