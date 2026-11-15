import SwiftUI
import QuickLook
import ARKit

/// "View in your space" row. Opens the dressed model in AR Quick Look at real-world scale.
/// Pass a product's previewAsset; nil opens the bare scan.
struct ViewInSpaceButton: View {
    var assetName: String?

    @State private var isPresented = false

    var body: some View {
        Button {
            isPresented = true
        } label: {
            HStack {
                Text("View in your space")
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.footnote.weight(.semibold))
            }
            .foregroundStyle(Theme.ink)
            .shoppyCard()
        }
        .buttonStyle(.plain)
        .fullScreenCover(isPresented: $isPresented) {
            if let url = ModelLibrary.bundledURL(assetName) {
                ARQuickLookView(url: url)
                    .ignoresSafeArea()
            } else {
                MessageState(eyebrow: "View in your space", title: "This look isn't ready for AR.", message: "A dressed model hasn't been prepared for this item. You can keep inspecting it in the 3D preview.") {
                    Button("Return to viewer") { isPresented = false }
                        .buttonStyle(.shoppyPrimary)
                }
            }
        }
    }
}

/// System AR Quick Look at true scale. On devices without AR it opens the object view.
private struct ARQuickLookView: UIViewControllerRepresentable {
    let url: URL

    func makeCoordinator() -> Coordinator {
        Coordinator(url: url)
    }

    func makeUIViewController(context: Context) -> UINavigationController {
        let controller = QLPreviewController()
        controller.dataSource = context.coordinator
        return UINavigationController(rootViewController: controller)
    }

    func updateUIViewController(_ controller: UINavigationController, context: Context) {}

    final class Coordinator: NSObject, QLPreviewControllerDataSource {
        let item: ARQuickLookPreviewItem

        init(url: URL) {
            item = ARQuickLookPreviewItem(fileAt: url)
            item.allowsContentScaling = false
        }

        func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
            1
        }

        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
            item
        }
    }
}
