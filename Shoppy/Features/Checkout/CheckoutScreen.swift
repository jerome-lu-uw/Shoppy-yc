import SwiftUI
import ShoppyCore

/// Demo checkout pushed from the Bag. No payment is taken and nothing ships.
struct CheckoutScreen: View {
    enum Phase {
        case form, processing, result(DemoOrder), declined
    }

    @Binding var isPresented: Bool
    var start = Phase.form

    @Environment(AppStore.self) private var store
    @State private var phase: Phase?
    @State private var isPlacing = false

    var body: some View {
        Group {
            switch phase ?? start {
            case .form:
                form
            case .processing:
                MessageState(eyebrow: "Demo checkout / Processing", title: "Checking your demo order.", message: "No charge or real order. I’m waiting for the simulated confirmation. Returning alone does not confirm an order.") {
                    ProgressView()
                }
            case .result(let order):
                OrderResultView(order: order) {
                    store.selectedTab = .discover
                    isPresented = false
                } viewOrder: {
                    store.selectedTab = .you
                    isPresented = false
                }
            case .declined:
                MessageState(eyebrow: "Demo checkout / Retry", title: "It didn’t go through.", message: "Your demo payment didn’t complete. The simulated payment was declined. Your bag and address are still here.") {
                    Button("Retry demo checkout") { place() }
                        .buttonStyle(.shoppyPrimary)
                        .disabled(isPlacing)
                    Button("Return to Bag") { isPresented = false }
                        .buttonStyle(.shoppySecondary)
                }
            }
        }
        .navigationBarBackButtonHidden()
        .toolbar(.hidden, for: .navigationBar)
    }

    private var form: some View {
        ShoppyScreen(eyebrow: "Shoppy / Demo", title: "Demo checkout", trailing: {
            Button("Bag") { isPresented = false }
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Theme.ink)
        }, content: {
            InfoBanner("No charge or real order")
            VStack(alignment: .leading, spacing: 6) {
                Eyebrow("Ship to · Fictional address")
                Text("\(store.profile.name) Demo")
                    .font(.headline)
                    .foregroundStyle(Theme.ink)
                Text("123 Example Street\nSample City, CA 00000")
                    .foregroundStyle(Theme.muted)
            }
            .shoppyCard()
            VStack(alignment: .leading, spacing: 4) {
                Text("Standard demo delivery")
                    .font(.headline)
                    .foregroundStyle(Theme.ink)
                Text("Simulated. Nothing will ship.")
                    .foregroundStyle(Theme.muted)
            }
            .shoppyCard()
            VStack(alignment: .leading, spacing: 10) {
                Eyebrow("Order summary")
                ForEach(store.orderLines(), id: \.variantID) { line in
                    summaryRow("\(line.title) · \(line.sizeLabel)\(line.quantity > 1 ? " × \(line.quantity)" : "")", (line.unitPriceCents * line.quantity).asPrice)
                }
                summaryRow("Demo shipping", 0.asPrice, muted: true)
                summaryRow("Demo tax", 0.asPrice, muted: true)
                Divider()
                summaryRow("Demo total", store.subtotalCents.asPrice, bold: true)
            }
            .shoppyCard()
            Text("Simulate checkout. No payment credentials needed.")
                .font(.subheadline)
                .foregroundStyle(Theme.muted)
        }, footer: {
            Button("Place demo order · \(store.subtotalCents.asPrice)") { place() }
                .buttonStyle(.shoppyPrimary)
                .disabled(isPlacing || !store.canCheckout)
        })
    }

    private func summaryRow(_ title: String, _ value: String, muted: Bool = false, bold: Bool = false) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
            Spacer()
            Text(value)
        }
        .fontWeight(bold ? .semibold : .regular)
        .foregroundStyle(muted ? Theme.muted : Theme.ink)
    }

    private func place() {
        guard !isPlacing else { return }
        isPlacing = true
        phase = .processing
        Task {
            defer { isPlacing = false }
            do {
                phase = .result(try await store.placeDemoOrder())
            } catch {
                phase = .declined
            }
        }
    }
}

private struct OrderResultView: View {
    let order: DemoOrder
    let keepDiscovering: () -> Void
    let viewOrder: () -> Void

    var body: some View {
        ShoppyScreen(eyebrow: "Demo order / Confirmed", title: "A good choice.", content: {
            Image(systemName: "checkmark")
                .font(.title.weight(.medium))
                .foregroundStyle(Theme.onLime)
                .frame(width: 76, height: 76)
                .background(Theme.lime, in: .circle)
                .accessibilityHidden(true)
            Text("Demo order placed")
                .font(.title.bold())
                .foregroundStyle(Theme.ink)
            Text("No payment was taken and no items will be shipped.")
                .foregroundStyle(Theme.muted)
            VStack(alignment: .leading, spacing: 10) {
                Eyebrow("Fictional order #\(order.number)")
                ForEach(order.lines, id: \.variantID) { line in
                    HStack(alignment: .firstTextBaseline) {
                        Text("\(line.title) · \(line.sizeLabel)")
                            .font(.headline)
                        Spacer()
                        Text((line.unitPriceCents * line.quantity).asPrice)
                    }
                    .foregroundStyle(Theme.ink)
                }
                Divider()
                HStack {
                    Text("Demo total").fontWeight(.semibold)
                    Spacer()
                    Text(order.totalCents.asPrice).fontWeight(.semibold)
                }
                .foregroundStyle(Theme.ink)
            }
            .shoppyCard()
            VStack(alignment: .leading, spacing: 8) {
                Eyebrow("Simulated status")
                HStack(spacing: 6) {
                    ForEach(Array(DemoOrderStatus.allCases.enumerated()), id: \.element) { index, status in
                        if index > 0 { Text("→").foregroundStyle(Theme.muted) }
                        Text(status.rawValue.capitalized)
                            .fontWeight(status == order.status ? .semibold : .regular)
                            .foregroundStyle(status == order.status ? Theme.ink : Theme.muted)
                    }
                }
                .font(.subheadline)
            }
            .shoppyCard()
        }, footer: {
            Button("Keep discovering", action: keepDiscovering)
                .buttonStyle(.shoppyPrimary)
            Button("View demo order", action: viewOrder)
                .buttonStyle(.shoppySecondary)
        })
    }
}

#if DEBUG
struct DecliningCheckout: CheckoutService {
    func placeDemoOrder(lines: [OrderLine], totalCents: Int) async throws -> DemoOrder {
        try await Task.sleep(for: .seconds(1.2))
        throw CheckoutError.declined
    }
}

extension CheckoutScreen {
    static func sampleOrder(_ store: AppStore) -> DemoOrder {
        var lines = store.orderLines()
        if lines.isEmpty, let product = store.catalog.first, let variant = product.variants.first {
            lines = [OrderLine(productID: product.id, variantID: variant.id, title: product.name, sizeLabel: variant.sizeLabel, quantity: 1, unitPriceCents: product.priceCents)]
        }
        return DemoOrder(number: "SH-00128", lines: lines, totalCents: lines.reduce(0) { $0 + $1.unitPriceCents * $1.quantity })
    }
}
#endif
