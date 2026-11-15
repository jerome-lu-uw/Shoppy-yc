import Combine
import ConvexMobile
import Foundation
import OSLog
import ShoppyCore

let backendLog = Logger(subsystem: "com.shoppy.app", category: "backend")

/// Mirrors AppStore state to Convex for a guest owner identified by a random UUID kept on device.
/// Every call fails soft: offline or server errors are logged and never reach the UI.
@MainActor
final class ConvexSync: RemoteSync {
    nonisolated let client: ConvexClient
    nonisolated let ownerId: String
    private var catalogSubscription: AnyCancellable?

    init(deploymentURL: String) {
        client = ConvexClient(deploymentUrl: deploymentURL)
        let key = "shoppy.ownerId"
        if let existing = UserDefaults.standard.string(forKey: key) {
            ownerId = existing
        } else {
            ownerId = UUID().uuidString
            UserDefaults.standard.set(ownerId, forKey: key)
        }
    }

    func start(store: AppStore) {
        catalogSubscription = client.subscribe(to: "catalog:list", yielding: [WireProduct].self)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion { backendLog.error("Catalog subscription ended: \(String(describing: error))") }
                },
                receiveValue: { products in
                    guard !products.isEmpty else { return }
                    store.catalog = products.map(\.model)
                }
            )

        Task { [weak store] in
            async let profile = load("profiles:get", as: WireProfile?.self)
            async let likes = load("likes:list", as: [WireLike].self)
            async let cart = load("cart:list", as: [WireCartItem].self)
            async let orders = load("orders:list", as: [WireOrder].self)
            let (remoteProfile, remoteLikes, remoteCart, remoteOrders) = await (profile, likes, cart, orders)
            guard let store else { return }
            store.applyRemote(
                profile: remoteProfile??.model,
                savedIDs: remoteLikes.map { $0.map(\.productId) },
                cart: remoteCart.map { $0.map(\.model) },
                orders: remoteOrders.map { $0.map(\.model) }
            )
        }
    }

    func setSaved(productID: String, saved: Bool) {
        fire("likes:set", ["productId": productID, "liked": saved])
    }

    func upsertCartItem(_ item: CartItem) {
        fire("cart:upsert", [
            "itemId": item.id,
            "productID": item.productID,
            "variantID": item.variantID,
            "quantity": Double(item.quantity),
            "sizeSource": item.sizeSource.rawValue,
            "needsSizeReview": item.needsSizeReview,
            "profileVersion": Double(item.profileVersion),
        ])
    }

    func removeCartItem(id: String) {
        fire("cart:remove", ["itemId": id])
    }

    func saveProfile(_ profile: BodyProfile) {
        var measurements: [String: ConvexEncodable?] = [:]
        for (kind, measurement) in profile.measurements {
            let entry: [String: ConvexEncodable?] = [
                "value": measurement.value,
                "source": measurement.source.rawValue,
                "updatedAt": (measurement.updatedAt.timeIntervalSince1970 * 1000).rounded(),
            ]
            measurements[kind.rawValue] = entry
        }
        fire("profiles:save", [
            "name": profile.name,
            "measurements": measurements,
            "fitPreference": profile.fitPreference.rawValue,
            "collection": profile.collection.rawValue,
            "units": profile.units.rawValue,
            "version": Double(profile.version),
        ])
    }

    private func fire(_ name: String, _ args: [String: ConvexEncodable?]) {
        var args = args
        args["ownerId"] = ownerId
        let client = client
        Task {
            do {
                try await client.mutation(name, with: args)
            } catch {
                backendLog.error("\(name) failed: \(String(describing: error))")
            }
        }
    }

    private func load<T: Decodable>(_ name: String, as type: T.Type) async -> T? {
        do {
            for try await value in client.subscribe(to: name, with: ["ownerId": ownerId], yielding: type).values {
                return value
            }
        } catch {
            backendLog.error("\(name) failed: \(String(describing: error))")
        }
        return nil
    }
}
