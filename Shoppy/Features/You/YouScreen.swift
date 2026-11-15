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
            RowCard(title: "Demo orders", value: store.orders.isEmpty ? nil : "\(store.orders.count)") { route = .orders }
        }
        .navigationDestination(item: $route) { route in
            switch route {
            case .editMeasurements: EditMeasurementsScreen()
            case .manageModel: ManageModelScreen()
            case .orders: DemoOrdersScreen()
            }
        }
    }
}

struct DemoOrdersScreen: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        ShoppyScreen(eyebrow: "Your fitting room", title: "Demo orders", trailing: { ExitButton(title: "Back") }) {
            if store.orders.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("No demo orders yet")
                        .font(.headline)
                        .foregroundStyle(Theme.ink)
                    Text("Demo checkout places a simulated order. Nothing is charged and nothing ships.")
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
                            Text("Simulated \u{00B7} \(order.status.rawValue.capitalized)")
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
                        Text("Demo order. No payment taken, nothing shipped.")
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
}
