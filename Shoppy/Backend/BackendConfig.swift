import Foundation

enum BackendConfig {
    /// The public Convex deployment URL from the bundled ConvexConfig.plist, or nil when none is set.
    static let deploymentURL: String? = {
        guard let url = Bundle.main.url(forResource: "ConvexConfig", withExtension: "plist"),
              let dictionary = NSDictionary(contentsOf: url),
              let value = (dictionary["DeploymentURL"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty
        else { return nil }
        return value
    }()
}
