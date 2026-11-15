import SwiftUI
import ShoppyCore

struct BagScreen: View {
    @Environment(AppStore.self) private var store
    @State private var showsCheckout = false
    @State private var reviewTarget: ReviewTarget?
    @State private var checkoutStart = CheckoutScreen.Phase.form

    private struct ReviewTarget: Identifiable {
        let id: String
        var recommendation: SizeRecommendation?
    }

    var body: some View {
        Group {
            if store.cart.isEmpty {
                MessageState(eyebrow: "Bag", title: "Ready for a good find.", message: "Your bag is empty. Explore the demo catalog and add a reviewed size when something feels right.") {
                    Button("Discover looks") { store.selectedTab = .discover }
                        .buttonStyle(.shoppyPrimary)
                }
            } else {
                bag
            }
        }
        .navigationDestination(isPresented: $showsCheckout) {
            CheckoutScreen(isPresented: $showsCheckout, start: checkoutStart)
        }
        .sheet(item: $reviewTarget) { target in
            if let item = store.cart.first(where: { $0.id == target.id }), let product = store.product(item.productID) {
                SizeReviewScreen(product: product, currentVariantID: item.variantID, recommendationOverride: target.recommendation) { variantID, source in
                    store.setVariant(itemID: item.id, variantID: variantID, sizeSource: source)
                }
            }
        }
        #if DEBUG
        .task { openDebugRoute() }
        #endif
    }

    private var needsReview: Bool {
        store.cart.contains(where: \.needsSizeReview)
    }

    private var bag: some View {
        ShoppyScreen(eyebrow: "Your edit", title: "Bag") {
            InfoBanner(needsReview ? "Measurements changed · Review these sizes" : "Sandbox checkout · No real charge")
            ForEach(store.cart) { item in
                if let product = store.product(item.productID) {
                    BagItemCard(item: item, product: product, groupNeedsReview: needsReview) {
                        reviewTarget = ReviewTarget(id: item.id)
                    } remove: {
                        store.removeFromBag(itemID: item.id)
                    }
                }
            }
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Subtotal").font(.headline)
                    Spacer()
                    Text(store.subtotalCents.asPrice).font(.headline)
                }
                .foregroundStyle(Theme.ink)
                Text("Shipping and tax are shown in Whop sandbox.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.muted)
            }
            .shoppyCard()
        } footer: {
            Button(store.canCheckout || !needsReview ? "Continue to sandbox checkout" : "Review sizes before checkout") {
                checkoutStart = .form
                showsCheckout = true
            }
            .buttonStyle(.shoppyPrimary)
            .disabled(!store.canCheckout)
        }
    }

    #if DEBUG
    private func openDebugRoute() {
        guard let route = DebugLaunch.route else { return }
        switch route {
        case "sizeReview":
            reviewTarget = store.cart.first.map { ReviewTarget(id: $0.id) }
        case "sizeReviewConfident":
            guard let item = store.cart.first, let product = store.product(item.productID) else { return }
            let variant = product.variants.first { $0.inStock && $0.sizeLabel == "M" } ?? product.variants.first { $0.inStock }
            let recommendation = SizeRecommendation(
                variantID: variant?.id,
                confidence: .confident,
                headline: "A little room to move.",
                summary: "Room through the chest; regular sleeve length.",
                comparisons: [
                    FitComparison(kind: .chest, basis: .garmentDimension, bodyValue: 98, bodySource: .entered, referenceValue: 108, ease: 10, note: "10 cm of room around the chest.")
                ],
                profileVersion: store.profile.version
            )
            reviewTarget = ReviewTarget(id: item.id, recommendation: recommendation)
        case "needsReview":
            var profile = store.profile
            profile.measurements[.chest] = Measurement(value: 101)
            store.updateProfile(profile)
        case "checkout":
            showsCheckout = true
        case "checkoutDecline":
            store.checkout = PreviewCheckout(fails: true)
            showsCheckout = true
        case "processing":
            checkoutStart = .starting
            showsCheckout = true
        case "orderResult":
            checkoutStart = .result(CheckoutScreen.sampleOrder(store))
            showsCheckout = true
        case "declined":
            checkoutStart = .failed(nil)
            showsCheckout = true
        default:
            break
        }
    }
    #endif
}

private struct BagItemCard: View {
    let item: CartItem
    let product: Product
    let groupNeedsReview: Bool
    let review: () -> Void
    let remove: () -> Void

    var body: some View {
        let variant = product.variant(item.variantID)
        HStack(alignment: .top, spacing: 16) {
            ModelPreviewView(assetName: product.previewAsset)
                .frame(width: 88, height: 120)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Eyebrow(product.brand)
                Text(product.name)
                    .font(.headline)
                    .foregroundStyle(Theme.ink)
                HStack(spacing: 12) {
                    Text("\(product.colorName) · \(variant?.sizeLabel ?? "—")")
                        .fontWeight(.medium)
                        .foregroundStyle(Theme.ink)
                    if !item.needsSizeReview {
                        Button("Change", action: review)
                            .foregroundStyle(Theme.ink)
                            .underline()
                    }
                }
                .font(.subheadline)
                Text("Qty \(item.quantity) · \(product.priceCents.asPrice)")
                .font(.subheadline)
                .foregroundStyle(Theme.muted)
                note
            }
            Button {
                withAnimation { remove() }
            } label: {
                Image(systemName: "trash")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.warn)
                    .frame(width: 44, height: 44)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remove \(product.name) from bag")
        }
        .shoppyCard()
    }

    @ViewBuilder
    private var note: some View {
        if item.needsSizeReview {
            Button(action: review) {
                Text("Review size ›")
            }
            .font(.subheadline.weight(.medium))
            .foregroundStyle(Theme.warn)
        } else if groupNeedsReview {
            Text("✓ Size reviewed")
                .font(.subheadline)
                .foregroundStyle(Theme.muted)
        } else {
            Text(item.sizeSource == .userChosen ? "You chose this size" : "Suggested for you")
                .font(.subheadline)
                .foregroundStyle(Theme.muted)
        }
    }
}

#Preview {
    NavigationStack { BagScreen() }
        .environment(AppStore(persistent: false))
}
