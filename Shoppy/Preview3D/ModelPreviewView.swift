import SwiftUI

enum ViewAngle: String, CaseIterable {
    case front, side, back
}

/// The dressed model on a studio backdrop. Pass the product's previewAsset; nil shows the default look.
/// Placeholder rendering until the RealityKit viewer lands; the initializer stays the same.
struct ModelPreviewView: View {
    var assetName: String?
    var angle: ViewAngle = .front
    var allowsRotation = false

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
