import SwiftUI
import ShoppyCore

enum YouRoute: String, Hashable {
    case editMeasurements, manageModel, orders
}

struct YouScreen: View {
    @Environment(AppStore.self) private var store
    @State private var route: YouRoute?

    init() {
        #if DEBUG
        _route = State(initialValue: DebugLaunch.route.flatMap(YouRoute.init(rawValue:)))
        #endif
    }

    var body: some View {
        ShoppyScreen(eyebrow: "Your fitting room", title: "You") {
            HStack(spacing: 16) {
                ModelPreviewView(assetName: nil)
                    .frame(width: 112, height: 136)
                VStack(alignment: .leading, spacing: 4) {
                    Text(store.profile.name)
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(Theme.ink)
                    Text("Your model")
                        .font(.headline)
                        .foregroundStyle(Theme.ink)
                    Text("Demo scan \u{00B7} Guest")
                        .font(.subheadline)
                        .foregroundStyle(Theme.muted)
                }
                Spacer(minLength: 0)
            }
            .shoppyCard()
            RowCard(title: "Edit measurements", value: store.profile.units == .metric ? "Metric" : "Imperial") { route = .editMeasurements }
            RowCard(title: "Manage model") { route = .manageModel }
            VStack(alignment: .leading, spacing: 10) {
                Text("Fit preference")
                    .foregroundStyle(Theme.ink)
                PillSegmented(
                    options: FitPreference.allCases.map { ($0, $0.rawValue.capitalized) },
                    selection: Binding(
                        get: { store.profile.fitPreference },
                        set: { newValue in
                            var profile = store.profile
                            profile.fitPreference = newValue
                            store.updateProfile(profile)
                        }
                    )
                )
            }
            .shoppyCard()
            RowCard(title: "Orders", value: store.orders.isEmpty ? nil : "\(store.orders.count)") { route = .orders }
        }
        .navigationDestination(item: $route) { route in
            switch route {
            case .editMeasurements: EditMeasurementsScreen()
            case .manageModel: ManageModelScreen()
            case .orders: OrdersScreen()
            }
        }
    }
}

struct OrdersScreen: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        ShoppyScreen(eyebrow: "Your fitting room", title: "Orders", trailing: { ExitButton(title: "Back") }) {
            if store.orders.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("No orders yet")
                        .font(.headline)
                        .foregroundStyle(Theme.ink)
                    Text("Whop sandbox checkout uses test payments. No real money moves and nothing ships.")
                        .font(.subheadline)
                        .foregroundStyle(Theme.muted)
                }
                .shoppyCard()
            } else {
                ForEach(store.orders) { order in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(order.number)
                                .font(.headline)
                                .foregroundStyle(Theme.ink)
                            Spacer()
                            Text("\(order.environment == .sandbox ? "Sandbox" : "Demo") \u{00B7} \(statusLabel(order.status))")
                                .font(.subheadline)
                                .foregroundStyle(Theme.muted)
                        }
                        ForEach(order.lines, id: \.self) { line in
                            Text("\(line.title) \u{00B7} \(line.sizeLabel) \u{00D7} \(line.quantity)")
                                .font(.subheadline)
                                .foregroundStyle(Theme.ink)
                        }
                        HStack {
                            Text("Total")
                            Spacer()
                            Text(order.totalCents.asPrice)
                                .fontWeight(.semibold)
                        }
                        .font(.subheadline)
                        .foregroundStyle(Theme.ink)
                        Text(order.environment == .sandbox ? "Whop sandbox order. No real charge or shipment." : "Legacy demo order. No charge or shipment.")
                            .font(.footnote)
                            .foregroundStyle(Theme.muted)
                    }
                    .shoppyCard()
                }
            }
        } footer: {
            EmptyView()
        }
    }

    private func statusLabel(_ status: OrderStatus) -> String {
        switch status {
        case .pendingPayment: "Pending"
        case .paid: "Paid"
        case .paymentFailed: "Failed"
        case .refunded: "Refunded"
        case .confirmed: "Confirmed"
        case .preparing: "Preparing"
        case .shipped: "Shipped"
        }
    }
}
