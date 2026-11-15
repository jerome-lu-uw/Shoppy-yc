import SwiftUI
import ShoppyCore

/// Product detail, pushed from a Discover card or a Saved tile.
struct ProductDetailScreen: View {
    let product: Product

    private enum Media: Hashable {
        case onYou, photos
    }

    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var media: Media = .onYou
    @State private var choice: SizeChoice?
    @State private var reviewing = false
    @State private var added = false

    var body: some View {
        let recommendation = store.recommendation(for: product)
        let variantID = choice?.variantID ?? recommendation.variantID
        let sizeLabel = variantID.flatMap { product.variant($0)?.sizeLabel }
        ShoppyScreen(eyebrow: product.brand, title: product.tagline) {
            Button("Back") { dismiss() }
                .font(.headline)
                .foregroundStyle(Theme.ink)
                .frame(minHeight: 44)
        } content: {
            PillSegmented(options: [(Media.onYou, "On you"), (.photos, "Product photos")], selection: $media)
            Group {
                if media == .onYou {
                    ProductPreviewTile(product: product)
                } else {
                    ProductPhoto(product: product)
                }
            }
            .frame(height: 320)
            VStack(alignment: .leading, spacing: 4) {
                Eyebrow(product.brand)
                Text(product.name)
                    .font(.title2.bold())
                    .foregroundStyle(Theme.ink)
                Text("\(product.priceCents.asPrice) · \(product.colorName)")
                    .foregroundStyle(Theme.muted)
            }
            RowCard(
                title: sizeLine(sizeLabel, recommendation),
                value: "Change"
            ) { reviewing = true }
            RowCard(title: "Why this size?") { reviewing = true }
            VStack(alignment: .leading, spacing: 8) {
                Text("Details")
                    .font(.headline)
                    .foregroundStyle(Theme.ink)
                ForEach(product.details, id: \.self) { detail in
                    Text("· \(detail)")
                        .font(.subheadline)
                        .foregroundStyle(Theme.muted)
                }
                if let sourceURL = product.sourceURL {
                    Link("View product source", destination: sourceURL)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.ink)
                }
            }
            .shoppyCard()
            Text(product.isFictional ? "Preview is an approximation. Demo catalog." : "Preview is an approximation.")
                .font(.footnote)
                .foregroundStyle(Theme.muted)
        } footer: {
            EmptyView()
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 8) {
            if added {
                InfoBanner("Added to your bag")
            }
            AddToBagButton(product: product, choice: choice, showsPrice: true) { added = true }
            }
            .padding(.horizontal, Theme.margin)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(Theme.ivory)
        }
        .sheet(isPresented: $reviewing) {
            SizeReviewScreen(product: product, currentVariantID: variantID) { id, source in
                choice = SizeChoice(variantID: id, source: source)
                reviewing = false
            }
        }
    }

    private func sizeLine(_ sizeLabel: String?, _ recommendation: SizeRecommendation) -> String {
        guard let sizeLabel else { return "No size available" }
        if choice != nil { return "Size \(sizeLabel)" }
        return recommendation.confidence == .confident ? "Suggested \(sizeLabel)" : "Size \(sizeLabel) · Limited data"
    }
}
