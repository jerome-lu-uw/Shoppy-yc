import SwiftUI

@main
struct ShoppyApp: App {
    #if DEBUG
    @State private var store = AppStore.launchStore()
    #else
    @State private var store = AppStore()
    #endif
    #if DEBUG
    @State private var showsSplash = DebugLaunch.route == nil || DebugLaunch.route == "splash"
    #else
    @State private var showsSplash = true
    #endif

    var body: some Scene {
        WindowGroup {
            ZStack {
                root
                    .accessibilityHidden(showsSplash)
                if showsSplash {
                    SplashScreen()
                        .transition(.opacity)
                        .zIndex(1)
                }
            }
                .environment(store)
                .tint(Theme.ink)
                .task {
                    await dismissSplash()
                }
                .task(priority: .userInitiated) {
                    await preloadInitialPreview()
                }
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

    private func preloadInitialPreview() async {
        let assetName = store.hasOnboarded ? store.feed.first?.previewAsset : nil
        guard let url = ModelLibrary.bundledURL(assetName) else { return }
        await ModelLibrary.shared.preload([url])
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

    @MainActor
    private func dismissSplash() async {
        guard showsSplash else { return }
        #if DEBUG
        guard DebugLaunch.route != "splash" else { return }
        #endif
        try? await Task.sleep(for: .seconds(1.8))
        guard !Task.isCancelled else { return }
        withAnimation(.easeInOut(duration: 0.35)) {
            showsSplash = false
        }
    }
}
