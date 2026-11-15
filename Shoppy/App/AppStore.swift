import Foundation
import Observation
import ShoppyCore

enum AppTab: Hashable {
    case discover, saved, bag, you
}

/// Single source of truth for the profile, catalog, saves, bag, and sandbox orders.
/// State persists to a local JSON file and mirrors to `sync` when one is attached.
@MainActor
@Observable
final class AppStore {
    private struct Snapshot: Codable {
        var profile = BodyProfile()
        var hasOnboarded = false
        var savedIDs: [String] = []
        var passedIDs: Set<String> = []
        var cart: [CartItem] = []
        var orders: [Order] = []
    }

    private(set) var profile: BodyProfile
    var hasOnboarded: Bool { didSet { persist() } }
    var catalog: [Product]
    private(set) var savedIDs: [String]
    private(set) var passedIDs: Set<String>
    private(set) var cart: [CartItem]
    private(set) var orders: [Order]
    var selectedTab: AppTab = .discover

    @ObservationIgnored var sync: RemoteSync?
    @ObservationIgnored var checkout: CheckoutService = UnavailableCheckout()
    @ObservationIgnored private let fileURL: URL?

    /// Pass `persistent: false` for previews and tests.
    init(persistent: Bool = true) {
        let url = persistent ? URL.applicationSupportDirectory.appending(path: "shoppy-state.json") : nil
        let snapshot = url.flatMap { try? Data(contentsOf: $0) }.flatMap { try? JSONDecoder().decode(Snapshot.self, from: $0) } ?? Snapshot()
        fileURL = url
        profile = snapshot.profile
        hasOnboarded = snapshot.hasOnboarded
        savedIDs = snapshot.savedIDs
        passedIDs = snapshot.passedIDs
        cart = snapshot.cart
        orders = snapshot.orders
        catalog = SeedCatalog.products
    }

    // MARK: Catalog

    func product(_ id: String) -> Product? {
        catalog.first { $0.id == id }
    }

    var savedProducts: [Product] {
        savedIDs.compactMap(product)
    }

    /// Products the user has neither saved nor passed, filtered by shopping collection.
    var feed: [Product] {
        catalog.filter { product in
            !savedIDs.contains(product.id) && !passedIDs.contains(product.id)
                && (profile.collection == .all || product.collection == .all || product.collection == profile.collection)
        }
    }

    func recommendation(for product: Product) -> SizeRecommendation {
        SizingEngine.recommend(product: product, profile: profile)
    }

    // MARK: Saves

    func isSaved(_ productID: String) -> Bool {
        savedIDs.contains(productID)
    }

    func setSaved(_ productID: String, _ saved: Bool) {
        savedIDs.removeAll { $0 == productID }
        if saved {
            savedIDs.append(productID)
            passedIDs.remove(productID)
        }
        sync?.setSaved(productID: productID, saved: saved)
        persist()
    }

    func setPassed(_ productID: String, _ passed: Bool) {
        if passed {
            passedIDs.insert(productID)
        } else {
            passedIDs.remove(productID)
        }
        persist()
    }

    func resetFeed() {
        passedIDs.removeAll()
        persist()
    }

    // MARK: Bag

    var bagCount: Int {
        cart.reduce(0) { $0 + $1.quantity }
    }

    var subtotalCents: Int {
        cart.reduce(0) { $0 + (product($1.productID)?.priceCents ?? 0) * $1.quantity }
    }

    var canCheckout: Bool {
        !cart.isEmpty && !cart.contains(where: \.needsSizeReview)
    }

    /// Adding the same product and size twice keeps one line, so repeated taps cannot duplicate it.
    func addToBag(productID: String, variantID: String, sizeSource: SizeSource) {
        guard !cart.contains(where: { $0.productID == productID && $0.variantID == variantID }) else { return }
        let item = CartItem(productID: productID, variantID: variantID, sizeSource: sizeSource, profileVersion: profile.version)
        cart.append(item)
        sync?.upsertCartItem(item)
        persist()
    }

    func removeFromBag(itemID: String) {
        cart.removeAll { $0.id == itemID }
        sync?.removeCartItem(id: itemID)
        persist()
    }

    /// Confirms or changes an item's size and clears its review flag.
    func setVariant(itemID: String, variantID: String, sizeSource: SizeSource) {
        guard let index = cart.firstIndex(where: { $0.id == itemID }) else { return }
        cart[index].variantID = variantID
        cart[index].sizeSource = sizeSource
        cart[index].needsSizeReview = false
        cart[index].profileVersion = profile.version
        sync?.upsertCartItem(cart[index])
        persist()
    }

    // MARK: Profile

    /// Saves a changed profile, bumps its version, and flags every bag item for a size review.
    /// Variants already in the bag are never replaced silently.
    func updateProfile(_ newProfile: BodyProfile) {
        guard newProfile != profile else { return }
        let sizingChanged = newProfile.measurements != profile.measurements || newProfile.fitPreference != profile.fitPreference
        profile = newProfile
        profile.version += 1
        if sizingChanged {
            for index in cart.indices {
                cart[index].needsSizeReview = true
                sync?.upsertCartItem(cart[index])
            }
        }
        sync?.saveProfile(profile)
        persist()
    }

    // MARK: Checkout

    func orderLines() -> [OrderLine] {
        cart.compactMap { item in
            guard let product = product(item.productID), let variant = product.variant(item.variantID) else { return nil }
            return OrderLine(productID: product.id, variantID: variant.id, title: product.name, sizeLabel: variant.sizeLabel, quantity: item.quantity, unitPriceCents: product.priceCents)
        }
    }

    func startCheckout() async throws -> CheckoutSession {
        guard canCheckout else { throw CheckoutError.invalidResponse }
        let session = try await checkout.startCheckout(items: cart, lines: orderLines())
        upsertOrder(session.order)
        persist()
        return session
    }

    func waitForCheckout(orderID: String) async throws -> Order {
        let order = try await checkout.waitForTerminalOrder(id: orderID)
        upsertOrder(order)
        if order.status == .paid {
            let clearedIDs = Set(order.clearedCartItemIDs)
            cart.removeAll { clearedIDs.contains($0.id) }
        }
        persist()
        return order
    }

    // MARK: Remote state

    /// Replaces local state with what the backend holds. Called by RemoteSync after it loads.
    func applyRemote(profile: BodyProfile?, savedIDs: [String]?, cart: [CartItem]?, orders: [Order]?) {
        if let profile { self.profile = profile }
        if let savedIDs { self.savedIDs = savedIDs }
        if let cart { self.cart = cart }
        if let orders { self.orders = orders }
        persist()
    }

    private func upsertOrder(_ order: Order) {
        if let index = orders.firstIndex(where: { $0.id == order.id }) {
            orders[index] = order
        } else {
            orders.insert(order, at: 0)
        }
    }

    private func persist() {
        guard let fileURL else { return }
        let snapshot = Snapshot(profile: profile, hasOnboarded: hasOnboarded, savedIDs: savedIDs, passedIDs: passedIDs, cart: cart, orders: orders)
        try? FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? JSONEncoder().encode(snapshot).write(to: fileURL, options: .atomic)
    }
}
