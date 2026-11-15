import SwiftUI
import RealityKit

enum ViewAngle: String, CaseIterable {
    case front, side, back

    var yaw: Float {
        switch self {
        case .front: 0
        case .side: -.pi / 2
        case .back: .pi
        }
    }
}

/// A 3D model on a studio backdrop.
/// - assetName: a bundled USDZ. Pass a product's previewAsset for the dressed look; nil shows "scan", the bare calibrated model.
/// - modelURL: a USDZ file on disk, such as an imported model. Takes precedence over assetName.
/// - angle: the camera snaps to this side whenever it changes.
/// - allowsRotation: lets the user drag to rotate. Leave false inside swipeable cards.
/// - resetCount: increment to snap back to `angle` after free rotation.
struct ModelPreviewView: View {
    var assetName: String?
    var modelURL: URL?
    var angle: ViewAngle = .front
    var allowsRotation = false
    var resetCount = 0

    @State private var pivot: Entity?
    @State private var loadFailed = false
    @State private var yaw: Float?
    @State private var yawAtDragStart: Float?

    private var source: URL? {
        modelURL ?? ModelLibrary.bundledURL(assetName)
    }

    var body: some View {
        ZStack {
            Theme.studio
            if let source, !loadFailed {
                RealityView { content in
                    content.camera = .virtual
                    let isStandaloneGarment = source.deletingPathExtension().lastPathComponent.hasPrefix("garment-")
                    let cameraHeight: Float = isStandaloneGarment ? 0.375 : 0.93
                    let cameraDistance: Float = isStandaloneGarment ? 1.8 : 4.05
                    let camera = PerspectiveCamera()
                    camera.camera.fieldOfViewInDegrees = 30
                    camera.look(at: [0, cameraHeight, 0], from: [0, cameraHeight, cameraDistance], relativeTo: nil)
                    content.add(camera)
                    let key = DirectionalLight()
                    key.light.intensity = 2200
                    key.look(at: .zero, from: [1.5, 3, 4], relativeTo: nil)
                    content.add(key)
                    let fill = DirectionalLight()
                    fill.light.intensity = 900
                    fill.look(at: .zero, from: [-3, 1.5, 2], relativeTo: nil)
                    content.add(fill)
                    guard let model = await ModelLibrary.shared.entity(for: source) else {
                        loadFailed = true
                        return
                    }
                    let pivot = Entity()
                    pivot.addChild(model)
                    content.add(pivot)
                    self.pivot = pivot
                } update: { _ in
                    guard yawAtDragStart == nil, let pivot else { return }
                    var transform = pivot.transform
                    transform.rotation = simd_quatf(angle: yaw ?? angle.yaw, axis: [0, 1, 0])
                    pivot.move(to: transform, relativeTo: pivot.parent, duration: 0.35, timingFunction: .easeInOut)
                }
                .id(source)
                .gesture(allowsRotation ? rotation : nil)
                if pivot == nil {
                    ProgressView()
                }
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "cube.transparent")
                        .font(.title)
                    Text("Preview unavailable")
                        .font(.footnote)
                }
                .foregroundStyle(Theme.muted)
            }
        }
        .clipShape(.rect(cornerRadius: Theme.cardRadius))
        .onChange(of: source) {
            pivot = nil
            loadFailed = false
        }
        .onChange(of: angle) {
            snap()
        }
        .onChange(of: resetCount) {
            snap()
        }
        .accessibilityElement()
        .accessibilityLabel(assetName == nil ? "Your model, \(angle.rawValue) view" : "Style preview, \(angle.rawValue) view")
    }

    private var rotation: some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { value in
                let start = yawAtDragStart ?? yaw ?? angle.yaw
                yawAtDragStart = start
                let newYaw = start + Float(value.translation.width) * 0.012
                yaw = newYaw
                pivot?.orientation = simd_quatf(angle: newYaw, axis: [0, 1, 0])
            }
            .onEnded { _ in
                yawAtDragStart = nil
            }
    }

    private func snap() {
        yaw = angle.yaw
    }
}

/// Loads each USDZ once and hands out clones, so many previews of one look share its meshes and textures.
@MainActor
final class ModelLibrary {
    static let shared = ModelLibrary()
    private var loaded: [URL: Entity] = [:]
    private var loading: [URL: Task<Entity?, Never>] = [:]

    nonisolated static func bundledURL(_ assetName: String?) -> URL? {
        Bundle.main.url(forResource: assetName ?? "scan", withExtension: "usdz")
    }

    func entity(for url: URL) async -> Entity? {
        guard let source = await sourceEntity(for: url) else { return nil }
        return source.clone(recursive: true)
    }

    func preload(_ urls: [URL]) async {
        for url in urls {
            _ = await sourceEntity(for: url)
        }
    }

    private func sourceEntity(for url: URL) async -> Entity? {
        if let entity = loaded[url] {
            return entity
        }
        if let task = loading[url] {
            return await task.value
        }
        let task = Task { @MainActor in
            try? await Entity(contentsOf: url)
        }
        loading[url] = task
        let entity = await task.value
        loading[url] = nil
        if let entity {
            loaded[url] = entity
        }
        return entity
    }
}
