import SwiftUI
import ShoppyCore

/// Full-screen "Explore 3D" inspection. Card swipes do not exist here; Done returns to the same card.
struct Explore3DScreen: View {
    let product: Product
    var onAdded: () -> Void = {}

    @Environment(\.dismiss) private var dismiss
    @State private var angle: ViewAngle = .front
    @State private var resetCount = 0

    var body: some View {
        ShoppyScreen(eyebrow: "Style preview", title: "Explore 3D") {
            Button("Done") { dismiss() }
                .font(.headline)
                .foregroundStyle(Theme.ink)
                .frame(minHeight: 44)
        } content: {
            ProductPreviewTile(product: product, angle: angle, allowsRotation: true, resetCount: resetCount)
                .frame(height: 340)
            PillSegmented(
                options: [(ViewAngle.front, "Front"), (.side, "Side"), (.back, "Back")],
                selection: $angle
            )
            HStack {
                Text("Drag to rotate")
                    .font(.subheadline)
                    .foregroundStyle(Theme.muted)
                Spacer()
                Button("Reset") { resetCount += 1 }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.ink)
                    .frame(minHeight: 44)
            }
            if product.previewAsset != nil {
                ViewInSpaceButton(assetName: product.previewAsset)
            }
        } footer: {
            EmptyView()
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(product.name)
                    .font(.headline)
                    .foregroundStyle(Theme.ink)
                Text("\(product.brand) · \(product.priceCents.asPrice)")
                    .font(.subheadline)
                    .foregroundStyle(Theme.muted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            AddToBagButton(product: product, onAdded: onAdded)
            }
            .padding(.horizontal, Theme.margin)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(Theme.ivory)
        }
    }
}
