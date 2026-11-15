import SwiftUI

/// "View in your space" row. Opens the dressed model in AR Quick Look at real-world scale.
/// Placeholder until the AR presenter lands; the initializer stays the same.
struct ViewInSpaceButton: View {
    var assetName: String?

    var body: some View {
        Button {} label: {
            HStack {
                Text("View in your space")
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.footnote.weight(.semibold))
            }
            .foregroundStyle(Theme.ink)
            .shoppyCard()
        }
        .buttonStyle(.plain)
    }
}
