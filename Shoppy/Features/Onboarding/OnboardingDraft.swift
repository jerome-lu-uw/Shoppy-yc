import Foundation
import Observation
import SceneKit
import ShoppyCore

enum ModelRoute: Hashable {
    case demo, upload, scan, create
}

enum OnboardingStep: Hashable {
    case basics, measurements, model, review, unreadable, unavailable(ModelRoute), reveal
}

/// Values typed during onboarding, held as text in the chosen unit until they are saved to the store.
@MainActor
@Observable
final class OnboardingDraft {
    var units: UnitSystem
    var collection: ShoppingCollection
    var fit: FitPreference
    var texts: [MeasurementKind: String] = [:]
    var route: ModelRoute = .demo
    var importedName: String?
    var importedURL: URL?
    var usedUpload = false

    init(profile: BodyProfile = BodyProfile()) {
        units = profile.units
        collection = profile.collection
        fit = profile.fitPreference
        for kind in MeasurementRules.editableKinds {
            if let value = profile.value(kind) {
                texts[kind] = MeasurementRules.text(forMetric: value, kind: kind, units: profile.units)
            }
        }
    }

    func setUnits(_ newUnits: UnitSystem) {
        guard newUnits != units else { return }
        for (kind, text) in texts {
            texts[kind] = MeasurementRules.convert(text, kind: kind, from: units, to: newUnits)
        }
        units = newUnits
    }

    func check(_ kind: MeasurementKind) -> MeasurementRules.Check {
        MeasurementRules.check(texts[kind] ?? "", kind: kind, units: units)
    }

    /// True when every listed field is empty or in range, and the required ones are filled.
    func isValid(_ kinds: [MeasurementKind], required: Set<MeasurementKind> = []) -> Bool {
        kinds.allSatisfy { kind in
            switch check(kind) {
            case .valid: true
            case .empty: !required.contains(kind)
            case .invalid: false
            }
        }
    }

    /// The base profile with the listed fields applied. Unchanged values keep their existing entry.
    func profile(from base: BodyProfile, kinds: [MeasurementKind]) -> BodyProfile {
        var profile = base
        profile.units = units
        profile.collection = collection
        profile.fitPreference = fit
        for kind in kinds {
            switch check(kind) {
            case .valid(let metric):
                if let existing = base.measurements[kind], abs(existing.value - metric) < 0.05 {
                    continue
                }
                profile.measurements[kind] = Measurement(value: metric)
            case .empty:
                profile.measurements[kind] = nil
            case .invalid:
                break
            }
        }
        return profile
    }

    /// Copies a picked USDZ into Application Support and checks that SceneKit can open it.
    /// Returns false for an unreadable file; a cancelled picker returns nil.
    func receive(_ result: Result<URL, Error>) async -> Bool? {
        let source: URL
        switch result {
        case .failure(let error):
            return (error as? CocoaError)?.code == .userCancelled ? nil : false
        case .success(let url):
            source = url
        }
        let didAccess = source.startAccessingSecurityScopedResource()
        defer { if didAccess { source.stopAccessingSecurityScopedResource() } }

        let directory = URL.applicationSupportDirectory.appending(path: "ImportedModels", directoryHint: .isDirectory)
        let destination = directory.appending(path: source.lastPathComponent)
        guard source.pathExtension.lowercased() == "usdz" else { return false }
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try? FileManager.default.removeItem(at: destination)
            try FileManager.default.copyItem(at: source, to: destination)
        } catch {
            return false
        }
        let readable = await Task.detached { (try? SCNScene(url: destination)) != nil }.value
        guard readable else {
            try? FileManager.default.removeItem(at: destination)
            return false
        }
        importedURL = destination
        importedName = destination.lastPathComponent
        route = .upload
        return true
    }
}
