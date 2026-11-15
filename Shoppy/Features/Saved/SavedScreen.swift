import SwiftUI
import ShoppyCore

struct SavedScreen: View {
    private enum Filter: Hashable {
        case all, tops, pants
    }

    @Environment(AppStore.self) private var store
    @State private var filter: Filter = .all
    @State private var detail: Product?

    private var products: [Product] {
        store.savedProducts.filter {
            switch filter {
            case .all: true
            case .tops: $0.category == .top
            case .pants: $0.category == .pants
            }
        }
    }

    var body: some View {
        Group {
            if store.savedProducts.isEmpty {
                MessageState(eyebrow: "Saved", title: "Your next favorites live here.", message: "Save a look in Discover to start your shortlist. Saving is a preference, not a purchase.") {
                    Button("Discover looks") { store.selectedTab = .discover }
                        .buttonStyle(.shoppyPrimary)
                }
            } else {
                grid
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(item: $detail) { ProductDetailScreen(product: $0) }
    }

    private var grid: some View {
        ShoppyScreen(eyebrow: "Your shortlist", title: "Saved") {
            PillSegmented(options: [(Filter.all, "All"), (.tops, "Tops"), (.pants, "Pants")], selection: $filter)
            if products.isEmpty {
                Text(filter == .tops ? "No saved tops yet." : "No saved pants yet.")
                    .foregroundStyle(Theme.muted)
                    .padding(.top, 8)
            }
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)], spacing: 20) {
                ForEach(products) { product in
                    tile(product)
                }
            }
        }
    }

    private func tile(_ product: Product) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Button { detail = product } label: {
                ProductPreviewTile(product: product)
                    .frame(height: 200)
            }
            .buttonStyle(.plain)
            .overlay(alignment: .topTrailing) {
                Button { store.setSaved(product.id, false) } label: {
                    Image(systemName: "heart.fill")
                        .foregroundStyle(Theme.ink)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("Remove \(product.name) from Saved")
            }
            Button { detail = product } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text(product.brand)
                        .font(.caption)
                        .foregroundStyle(Theme.muted)
                    Text(product.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.ink)
                        .multilineTextAlignment(.leading)
                    Text(product.priceCents.asPrice)
                        .font(.subheadline)
                        .foregroundStyle(Theme.muted)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
        }
    }
}
