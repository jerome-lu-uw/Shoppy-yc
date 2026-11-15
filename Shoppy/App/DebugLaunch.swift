#if DEBUG
import Foundation
import ShoppyCore

/// Launch arguments for screenshots and smoke tests, for example:
/// xcrun simctl launch <device> com.jeromelu.shoppy -shoppySeed YES -shoppyTab bag -shoppyRoute checkout
enum DebugLaunch {
    /// Start onboarded with the preview profile, two products saved, and two in the bag. Nothing is written to disk.
    static var seedsDemoState: Bool { UserDefaults.standard.bool(forKey: "shoppySeed") }

    static var tab: AppTab? {
        switch UserDefaults.standard.string(forKey: "shoppyTab") {
        case "discover": .discover
        case "saved": .saved
        case "bag": .bag
        case "you": .you
        default: nil
        }
    }

    /// Free-form route a feature may read to open one of its own screens directly.
    static var route: String? { UserDefaults.standard.string(forKey: "shoppyRoute") }
}

extension AppStore {
    static func launchStore() -> AppStore {
        let store = AppStore(persistent: !DebugLaunch.seedsDemoState)
        if DebugLaunch.seedsDemoState {
            store.checkout = PreviewCheckout()
            store.hasOnboarded = true
            var profile = BodyProfile(name: "Alex")
            profile.measurements = [
                .height: Measurement(value: 178),
                .weight: Measurement(value: 75),
                .chest: Measurement(value: 98),
                .waist: Measurement(value: 82),
            ]
            store.updateProfile(profile)
            for product in store.catalog.prefix(2) {
                store.setSaved(product.id, true)
                if let variantID = store.recommendation(for: product).variantID {
                    store.addToBag(productID: product.id, variantID: variantID, sizeSource: .suggested)
                }
            }
        }
        if let tab = DebugLaunch.tab {
            store.selectedTab = tab
        }
        return store
    }
}
#endif
