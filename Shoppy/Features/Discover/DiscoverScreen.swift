import SwiftUI

struct DiscoverScreen: View {
    var body: some View {
        ShoppyScreen(eyebrow: "shoppy", title: "For you") {
            ModelPreviewView()
                .frame(height: 340)
        }
    }
}
