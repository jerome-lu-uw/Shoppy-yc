import SwiftUI

enum ViewAngle: String, CaseIterable {
    case front, side, back
}

/// A 3D model on a studio backdrop.
/// - assetName: a bundled USDZ. Pass a product's previewAsset for the dressed look; nil shows "scan", the bare calibrated model.
/// - modelURL: a USDZ file on disk, such as an imported model. Takes precedence over assetName.
/// - angle: the camera snaps to this side whenever it changes.
/// - allowsRotation: lets the user drag to rotate. Leave false inside swipeable cards.
/// - resetCount: increment to snap back to `angle` after free rotation.
/// Placeholder rendering until the RealityKit viewer lands; the initializer stays the same.
struct ModelPreviewView: View {
    var assetName: String?
    var modelURL: URL?
    var angle: ViewAngle = .front
    var allowsRotation = false
    var resetCount = 0

    var body: some View {
        ZStack {
            Theme.studio
            Image(systemName: "figure.stand")
                .resizable()
                .scaledToFit()
                .foregroundStyle(Theme.muted.opacity(0.5))
                .padding(.vertical, 24)
                .scaleEffect(x: angle == .side ? 0.6 : 1)
        }
        .clipShape(.rect(cornerRadius: Theme.cardRadius))
        .accessibilityLabel("Style preview, \(angle.rawValue) view")
    }
}
