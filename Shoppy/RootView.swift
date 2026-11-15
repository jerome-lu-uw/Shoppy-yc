import SwiftUI

struct RootView: View {
    var body: some View {
        TabView {
            Tab("Discover", systemImage: "sparkles") {
                NavigationStack {
                    ContentUnavailableView("Discover", systemImage: "sparkles", description: Text("Your looks will appear here."))
                        .navigationTitle("Discover")
                }
            }
            Tab("Saved", systemImage: "heart") {
                NavigationStack {
                    ContentUnavailableView("Nothing saved yet", systemImage: "heart", description: Text("Swipe right on a look to save it."))
                        .navigationTitle("Saved")
                }
            }
            Tab("Bag", systemImage: "bag") {
                NavigationStack {
                    ContentUnavailableView("Your bag is empty", systemImage: "bag", description: Text("Add a suggested size from any look."))
                        .navigationTitle("Bag")
                }
            }
            Tab("You", systemImage: "person.crop.circle") {
                NavigationStack {
                    ContentUnavailableView("You", systemImage: "person.crop.circle", description: Text("Your model and measurements live here."))
                        .navigationTitle("You")
                }
            }
        }
    }
}

#Preview {
    RootView()
}
