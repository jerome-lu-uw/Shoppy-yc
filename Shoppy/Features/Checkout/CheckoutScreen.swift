import SafariServices
import SwiftUI
import ShoppyCore

/// Whop sandbox checkout pushed from the Bag. Test payments never move money or trigger shipment.
struct CheckoutScreen: View {
    enum Phase {
        case form, membership, starting, waiting(Order), result(Order), failed(Order?), unavailable
    }

    private static let membershipURL = URL(string: "https://sandbox.whop.com/shoppy/shoppy-membership/")!

    @Binding var isPresented: Bool
    var start = Phase.form

    @Environment(AppStore.self) private var store
    @State private var phase: Phase?
    @State private var isPlacing = false
    @State private var checkoutURL: URL?
    @State private var presentedCheckout: HostedCheckout?
    @State private var monitorTask: Task<Void, Never>?

    var body: some View {
        Group {
            switch phase ?? start {
            case .form:
                form
            case .membership:
                membership
            case .starting:
                MessageState(eyebrow: "Whop sandbox / Starting", title: "Preparing secure checkout.", message: "Shoppy is validating your bag and asking Whop for a sandbox checkout. No real money can move.") {
                    ProgressView()
                }
            case .waiting(let order):
                waiting(order)
            case .result(let order):
                OrderResultView(order: order) {
                    store.selectedTab = .discover
                    isPresented = false
                } viewOrder: {
                    store.selectedTab = .you
                    isPresented = false
                }
            case .failed(let order):
                MessageState(eyebrow: "Whop sandbox / Retry", title: "The sandbox payment didn’t complete.", message: order?.failureMessage ?? "Whop could not confirm this test payment. Your bag is unchanged.") {
                    Button("Retry in Whop sandbox") { beginCheckout() }
                        .buttonStyle(.shoppyPrimary)
                        .disabled(isPlacing)
                    Button("Return to Bag") { isPresented = false }
                        .buttonStyle(.shoppySecondary)
                }
            case .unavailable:
                MessageState(eyebrow: "Whop sandbox / Setup", title: "Checkout isn’t configured yet.", message: "Connect the Convex backend and add the Whop sandbox environment variables before testing checkout.") {
                    Button("Return to Bag") { isPresented = false }
                        .buttonStyle(.shoppyPrimary)
                }
            }
        }
        .navigationBarBackButtonHidden()
        .toolbar(.hidden, for: .navigationBar)
        .sheet(item: $presentedCheckout) { checkout in
            SafariView(url: checkout.url)
                .ignoresSafeArea()
        }
        .onDisappear {
            monitorTask?.cancel()
        }
    }

    private var form: some View {
        ShoppyScreen(eyebrow: "Shoppy / Sandbox", title: "Checkout", trailing: {
            Button("Bag") { isPresented = false }
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Theme.ink)
        }, content: {
            InfoBanner("Whop sandbox · No real charge or shipment")
            VStack(alignment: .leading, spacing: 6) {
                Eyebrow("Shipping address")
                Text("Collected securely by Whop")
                    .font(.headline)
                    .foregroundStyle(Theme.ink)
                Text("Use test details only. Shoppy does not fulfill or ship this sandbox order.")
                    .foregroundStyle(Theme.muted)
            }
            .shoppyCard()
            VStack(alignment: .leading, spacing: 4) {
                Text("Sandbox checkout")
                    .font(.headline)
                    .foregroundStyle(Theme.ink)
                Text("Whop accepts test cards; no money moves.")
                    .foregroundStyle(Theme.muted)
            }
            .shoppyCard()
            VStack(alignment: .leading, spacing: 10) {
                Eyebrow("Order summary")
                ForEach(store.orderLines(), id: \.variantID) { line in
                    summaryRow("\(line.title) · \(line.sizeLabel)\(line.quantity > 1 ? " × \(line.quantity)" : "")", (line.unitPriceCents * line.quantity).asPrice)
                }
                summaryRow("Shipping", "Shown by Whop", muted: true)
                summaryRow("Tax", "Shown by Whop", muted: true)
                Divider()
                summaryRow("Subtotal", store.subtotalCents.asPrice, bold: true)
            }
            .shoppyCard()
            Text("A signed Whop webhook—not returning from the browser—confirms the sandbox payment.")
                .font(.subheadline)
                .foregroundStyle(Theme.muted)
        }, footer: {
            Button("Continue with Whop · \(store.subtotalCents.asPrice)") { beginMembership() }
                .buttonStyle(.shoppyPrimary)
                .disabled(isPlacing || !store.canCheckout)
        })
    }

    private var membership: some View {
        MessageState(
            eyebrow: "Whop sandbox / Membership",
            title: "Join Shoppy on Whop.",
            message: "Sign in to Whop and join the free Shoppy Membership. Return here afterward to continue to sandbox checkout."
        ) {
            Button("Open Shoppy Membership") {
                presentedCheckout = HostedCheckout(url: Self.membershipURL)
            }
            .buttonStyle(.shoppyPrimary)
            Button("I joined · Continue to checkout") {
                beginCheckout()
            }
            .buttonStyle(.shoppySecondary)
            Button("Return to Bag") {
                isPresented = false
            }
            .buttonStyle(.shoppyLink)
            Text("Sandbox interstitial only · Shoppy does not verify membership status.")
                .font(.footnote)
                .foregroundStyle(Theme.muted)
        }
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

    private func waiting(_ order: Order) -> some View {
        MessageState(
            eyebrow: "Whop sandbox / Waiting",
            title: "Complete checkout in Whop.",
            message: "Order \(order.number) stays pending until Convex receives Whop’s signed webhook. Closing or returning from the browser does not confirm payment."
        ) {
            ProgressView()
            if let checkoutURL {
                Button("Open Whop sandbox") {
                    presentedCheckout = HostedCheckout(url: checkoutURL)
                }
                .buttonStyle(.shoppyPrimary)
            }
            Button("Return to Bag") {
                monitorTask?.cancel()
                isPresented = false
            }
            .buttonStyle(.shoppySecondary)
        }
    }

    private func beginCheckout() {
        guard !isPlacing else { return }
        monitorTask?.cancel()
        isPlacing = true
        phase = .starting
        monitorTask = Task {
            defer { isPlacing = false }
            do {
                let session = try await store.startCheckout()
                try Task.checkCancellation()
                checkoutURL = session.checkoutURL
                if session.order.status.isPaymentTerminal {
                    phase = session.order.status == .paid ? .result(session.order) : .failed(session.order)
                    return
                }
                phase = .waiting(session.order)
                if let url = session.checkoutURL {
                    presentedCheckout = HostedCheckout(url: url)
                }
                let order = try await store.waitForCheckout(orderID: session.order.id)
                try Task.checkCancellation()
                presentedCheckout = nil
                phase = order.status == .paid ? .result(order) : .failed(order)
            } catch is CancellationError {
                return
            } catch CheckoutError.unavailable {
                phase = .unavailable
            } catch {
                phase = .failed(nil)
            }
        }
    }

    private func beginMembership() {
        phase = .membership
        presentedCheckout = HostedCheckout(url: Self.membershipURL)
    }
}

private struct OrderResultView: View {
    let order: Order
    let keepDiscovering: () -> Void
    let viewOrder: () -> Void

    var body: some View {
        ShoppyScreen(eyebrow: "Whop sandbox / Confirmed", title: "A good choice.", content: {
            Image(systemName: "checkmark")
                .font(.title.weight(.medium))
                .foregroundStyle(Theme.onLime)
                .frame(width: 76, height: 76)
                .background(Theme.lime, in: .circle)
                .accessibilityHidden(true)
            Text("Sandbox payment confirmed")
                .font(.title.bold())
                .foregroundStyle(Theme.ink)
            Text("Whop confirmed a test payment. No real money moved and nothing will ship.")
                .foregroundStyle(Theme.muted)
            VStack(alignment: .leading, spacing: 10) {
                Eyebrow("Order #\(order.number)")
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
                    Text("Subtotal").fontWeight(.semibold)
                    Spacer()
                    Text(order.totalCents.asPrice).fontWeight(.semibold)
                }
                .foregroundStyle(Theme.ink)
            }
            .shoppyCard()
            VStack(alignment: .leading, spacing: 8) {
                Eyebrow("Payment status")
                Text("Paid · Whop sandbox")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.ink)
            }
            .shoppyCard()
        }, footer: {
            Button("Keep discovering", action: keepDiscovering)
                .buttonStyle(.shoppyPrimary)
            Button("View order", action: viewOrder)
                .buttonStyle(.shoppySecondary)
        })
    }
}

private struct HostedCheckout: Identifiable {
    let url: URL
    var id: String { url.absoluteString }
}

private struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }

    func updateUIViewController(_ controller: SFSafariViewController, context: Context) {}
}

#if DEBUG
extension CheckoutScreen {
    static func sampleOrder(_ store: AppStore) -> Order {
        var lines = store.orderLines()
        if lines.isEmpty, let product = store.catalog.first, let variant = product.variants.first {
            lines = [OrderLine(productID: product.id, variantID: variant.id, title: product.name, sizeLabel: variant.sizeLabel, quantity: 1, unitPriceCents: product.priceCents)]
        }
        return Order(
            number: "SH-00128",
            lines: lines,
            totalCents: lines.reduce(0) { $0 + $1.unitPriceCents * $1.quantity },
            status: .paid,
            clearedCartItemIDs: store.cart.map(\.id),
            paidAt: .now
        )
    }
}
#endif
