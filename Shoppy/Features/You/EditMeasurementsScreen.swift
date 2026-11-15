import SwiftUI

/// "Measurements" editor. Presented as a sheet or pushed; saves through AppStore.updateProfile.
struct EditMeasurementsScreen: View {
    var body: some View {
        ShoppyScreen(eyebrow: "Your profile / Edit", title: "Measurements") {
            Text("Coming up.")
                .foregroundStyle(Theme.muted)
        }
    }
}
