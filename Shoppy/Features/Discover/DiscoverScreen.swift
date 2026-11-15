import SwiftUI
import ShoppyCore

struct DiscoverScreen: View {
    private struct Decision {
        let productID: String
        let saved: Bool
    }

    @Environment(AppStore.self) private var store
    @State private var garments = Set(GarmentCategory.allCases)
    @State private var history: [Decision] = []
    @State private var drag: CGFloat = 0
    @State private var isDeciding = false
    @State private var title = "For you"
    @State private var flashTask: Task<Void, Never>?
    @State private var showFilters = false
    @State private var exploring: Product?
    @State private var detail: Product?

    private var current: Product? {
        store.feed.first { garments.contains($0.category) }
    }

    var body: some View {
        Group {
            if let product = current {
                feed(product)
            } else {
                MessageState(eyebrow: "Discover", title: "You've seen it all.", message: "Start over to look through the catalog again, or change your edit.") {
                    Button("Start over") {
                        garments = Set(GarmentCategory.allCases)
                        history = []
                        store.resetFeed()
                    }
                    .buttonStyle(.shoppyPrimary)
                    Button("Edit filters") { showFilters = true }
                        .buttonStyle(.shoppySecondary)
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(item: $detail) { ProductDetailScreen(product: $0) }
        .sheet(isPresented: $showFilters) {
            DiscoverFiltersSheet(garments: $garments)
                .presentationDetents([.medium, .large])
        }
        .fullScreenCover(item: $exploring) { product in
            Explore3DScreen(product: product) {
                exploring = nil
                flash("Added to your bag")
            }
        }
        #if DEBUG
        .task {
            switch DebugLaunch.route {
            case "explore3d": exploring = store.catalog.first
            case "product": detail = store.catalog.first
            case "filters": showFilters = true
            case "fresh": store.catalog.forEach { store.setSaved($0.id, false) }
            default: break
            }
        }
        #endif
    }

    private func feed(_ product: Product) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.spacing) {
                Text("shoppy")
                    .foregroundStyle(Theme.muted)
                HStack(alignment: .firstTextBaseline) {
                    Text(title)
                        .font(.largeTitle.bold())
                        .foregroundStyle(Theme.ink)
                        .accessibilityAddTraits(.isHeader)
                    Spacer()
                    Button { showFilters = true } label: {
                        Image(systemName: "slider.horizontal.3")
                            .font(.title3)
                            .foregroundStyle(Theme.ink)
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("Filters")
                }
                .padding(.bottom, 8)
                card(product)
                    .id(product.id)
                    .offset(x: drag)
                    .rotationEffect(.degrees(Double(drag) / 25))
                    .overlay(alignment: drag > 0 ? .topLeading : .topTrailing) {
                        stamp(drag > 0 ? "Saved" : "Pass")
                            .opacity(min(abs(drag) / 100, 1))
                            .padding(16)
                    }
                    .gesture(
                        DragGesture(minimumDistance: 16)
                            .onChanged { drag = $0.translation.width }
                            .onEnded { value in
                                if abs(value.translation.width) > 110 {
                                    decide(saved: value.translation.width > 0)
                                } else {
                                    withAnimation(.spring(duration: 0.35, bounce: 0.3)) { drag = 0 }
                                }
                            }
                    )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Theme.margin)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .background(Theme.ivory.ignoresSafeArea())
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    Button { undo() } label: {
                        Label("Undo", systemImage: "arrow.uturn.backward")
                            .labelStyle(.iconOnly)
                            .frame(width: Theme.buttonHeight, height: Theme.buttonHeight)
                            .background(Theme.card, in: .circle)
                            .overlay(Circle().stroke(Theme.line))
                            .foregroundStyle(Theme.ink)
                    }
                    .disabled(history.isEmpty)
                    .opacity(history.isEmpty ? 0.4 : 1)
                    .accessibilityLabel("Undo")
                    Button { decide(saved: false) } label: {
                        Label("Pass", systemImage: "xmark")
                    }
                    .buttonStyle(.shoppySecondary)
                    Button { decide(saved: true) } label: {
                        Label("Save", systemImage: "heart")
                    }
                    .buttonStyle(.shoppySecondary)
                }
                AddToBagButton(product: product) { flash("Added to your bag") }
            }
            .padding(.horizontal, Theme.margin)
            .padding(.vertical, 12)
            .background(Theme.ivory)
        }
    }

    private func card(_ product: Product) -> some View {
        let recommendation = store.recommendation(for: product)
        let size = recommendation.variantID.flatMap { product.variant($0)?.sizeLabel }
        let fitLine = recommendation.confidence == .confident && size != nil
            ? "\(product.colorName) · Suggested \(size!) · Estimated fit"
            : "\(product.colorName) · Estimated fit · Limited data"
        return VStack(alignment: .leading, spacing: Theme.spacing) {
            ProductPreviewTile(product: product)
                .frame(height: 360)
                .overlay(alignment: .topLeading) {
                    if product.previewAsset != nil {
                        Eyebrow("Style preview").padding(16)
                    }
                }
                .overlay(alignment: .bottomTrailing) {
                    if product.previewAsset != nil {
                        Button { exploring = product } label: {
                            Label("Explore 3D", systemImage: "cube")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Theme.ink)
                                .padding(.horizontal, 14)
                                .frame(minHeight: 44)
                                .background(Theme.card, in: .capsule)
                                .overlay(Capsule().stroke(Theme.line))
                        }
                        .padding(12)
                    }
                }
            Button { detail = product } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(product.brand)
                        .font(.subheadline)
                        .foregroundStyle(Theme.muted)
                    HStack(alignment: .firstTextBaseline) {
                        Text(product.name)
                            .font(.title3.bold())
                        Spacer()
                        Text(product.priceCents.asPrice)
                            .font(.title3.bold())
                    }
                    .foregroundStyle(Theme.ink)
                    Text(fitLine)
                        .font(.subheadline)
                        .foregroundStyle(Theme.muted)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityHint("Opens product details")
        }
    }

    private func stamp(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.headline)
            .foregroundStyle(Theme.ink)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(drag > 0 ? Theme.lime : Theme.card, in: .capsule)
            .overlay(Capsule().stroke(Theme.line))
    }

    private func decide(saved: Bool) {
        guard !isDeciding, let product = current else { return }
        isDeciding = true
        withAnimation(.easeIn(duration: 0.2)) { drag = saved ? 500 : -500 }
        Task {
            try? await Task.sleep(for: .milliseconds(200))
            if saved {
                store.setSaved(product.id, true)
            } else {
                store.setPassed(product.id, true)
            }
            history.append(Decision(productID: product.id, saved: saved))
            flash(saved ? "Saved. Next up." : "Next look")
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) { drag = 0 }
            isDeciding = false
        }
    }

    private func undo() {
        guard !isDeciding, let last = history.popLast() else { return }
        if last.saved {
            store.setSaved(last.productID, false)
        } else {
            store.setPassed(last.productID, false)
        }
        flash("For you")
    }

    private func flash(_ text: String) {
        flashTask?.cancel()
        title = text
        guard text != "For you" else { return }
        flashTask = Task {
            try? await Task.sleep(for: .seconds(1.8))
            if !Task.isCancelled { title = "For you" }
        }
    }
}
