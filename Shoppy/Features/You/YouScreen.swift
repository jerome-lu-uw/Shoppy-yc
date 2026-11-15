import SwiftUI

struct YouScreen: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        ShoppyScreen(eyebrow: "Your fitting room", title: "You") {
            RowCard(title: "Edit measurements", value: store.profile.units == .metric ? "Metric" : "Imperial") {}
            RowCard(title: "Fit preference", value: store.profile.fitPreference.rawValue.capitalized) {}
        }
    }
}
