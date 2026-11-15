import SwiftUI
import ShoppyCore

/// "Why we suggested M." / "Review your size." Presented as a sheet or pushed.
/// Calls onConfirm with the chosen variant; the caller decides what to do with it and dismisses.
struct SizeReviewScreen: View {
    let product: Product
    var currentVariantID: String?
    let onConfirm: (_ variantID: String, _ source: SizeSource) -> Void

    @Environment(AppStore.self) private var store

    var body: some View {
        let recommendation = store.recommendation(for: product)
        ShoppyScreen(eyebrow: "Sizing / \(product.brand)", title: "Review your size.") {
            Text(recommendation.summary)
                .foregroundStyle(Theme.muted)
        } footer: {
            if let variantID = currentVariantID ?? recommendation.variantID, let variant = product.variant(variantID) {
                Button("Keep \(variant.sizeLabel)") { onConfirm(variantID, .suggested) }
                    .buttonStyle(.shoppyPrimary)
            }
        }
    }
}
