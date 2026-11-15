#if DEBUG
import SwiftUI

/// Opened with `-shoppyRoute preview3d` (optionally `-shoppyAsset <name>`) to check the viewer on its own.
struct Preview3DDebugScreen: View {
    @State private var angle = ViewAngle.front
    @State private var resetCount = 0
    private let asset = UserDefaults.standard.string(forKey: "shoppyAsset") ?? "look-smooth-spacer-quarter-zip"

    var body: some View {
        ShoppyScreen(eyebrow: "Style preview", title: "Explore 3D") {
            ModelPreviewView(assetName: asset == "scan" ? nil : asset, angle: angle, allowsRotation: true, resetCount: resetCount)
                .frame(height: 420)
            PillSegmented(options: ViewAngle.allCases.map { ($0, $0.rawValue.capitalized) }, selection: $angle)
            Button("Reset") { resetCount += 1 }
                .buttonStyle(.shoppyLink)
            ViewInSpaceButton(assetName: asset == "scan" ? nil : asset)
        }
        .onAppear {
            if let start = UserDefaults.standard.string(forKey: "shoppyAngle").flatMap(ViewAngle.init) {
                angle = start
            }
        }
    }
}
#endif
