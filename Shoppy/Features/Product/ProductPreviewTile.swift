import SwiftUI
import ShoppyCore

/// A product's style preview: the 3D model when a preview asset exists, otherwise the product photo or a neutral tile.
struct ProductPreviewTile: View {
    let product: Product
    var angle: ViewAngle = .front
    var allowsRotation = false
    var resetCount = 0

    var body: some View {
        if let asset = product.previewAsset {
            ModelPreviewView(assetName: asset, angle: angle, allowsRotation: allowsRotation, resetCount: resetCount)
        } else {
            ProductPhoto(product: product)
        }
    }
}

/// The retailer or demo photo on a studio tile, or "Preview unavailable" when there is none.
struct ProductPhoto: View {
    let product: Product

    var body: some View {
        ZStack {
            Theme.studio
            if let url = product.imageURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    case .empty:
                        ProgressView()
                    default:
                        unavailable
                    }
                }
            } else {
                unavailable
            }
        }
        .clipShape(.rect(cornerRadius: Theme.cardRadius))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(product.imageURL == nil ? "Preview unavailable" : "Product photo of \(product.name)")
    }

    private var unavailable: some View {
        VStack(spacing: 8) {
            Image(systemName: "photo")
                .font(.largeTitle)
            Text("Preview unavailable")
                .font(.subheadline)
        }
        .foregroundStyle(Theme.muted)
    }
}

/// Size the shopper chose in a size review; nil means "use the suggestion".
struct SizeChoice: Equatable {
    var variantID: String
    var source: SizeSource
}

/// "Add to Bag · M" button. Adds the suggested size when the estimate is confident, otherwise asks for a size review first.
struct AddToBagButton: View {
    let product: Product
    var choice: SizeChoice?
    var showsPrice = false
    var onAdded: () -> Void = {}

    @Environment(AppStore.self) private var store
    @State private var reviewing = false

    var body: some View {
        let recommendation = store.recommendation(for: product)
        let variantID = choice?.variantID ?? recommendation.variantID
        Button {
            if let choice {
                add(choice.variantID, choice.source)
            } else if recommendation.confidence == .confident, let id = recommendation.variantID {
                add(id, .suggested)
            } else {
                reviewing = true
            }
        } label: {
            Text(label(variantID))
        }
        .buttonStyle(.shoppyPrimary)
        .disabled(variantID == nil)
        .sheet(isPresented: $reviewing) {
            SizeReviewScreen(product: product, currentVariantID: recommendation.variantID) { id, source in
                reviewing = false
                add(id, source)
            }
        }
    }

    private func label(_ variantID: String?) -> String {
        guard let variantID, let size = product.variant(variantID)?.sizeLabel else { return "No size available" }
        return showsPrice ? "Add to Bag · \(size) · \(product.priceCents.asPrice)" : "Add to Bag · \(size)"
    }

    private func add(_ variantID: String, _ source: SizeSource) {
        store.addToBag(productID: product.id, variantID: variantID, sizeSource: source)
        onAdded()
    }
}
