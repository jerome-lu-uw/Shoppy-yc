import Foundation

public enum ShoppingCollection: String, Codable, CaseIterable, Sendable {
    case women, men, all
}

public enum FitPreference: String, Codable, CaseIterable, Sendable {
    case close, regular, relaxed
}

public enum UnitSystem: String, Codable, CaseIterable, Sendable {
    case metric, imperial
}

public enum MeasurementKind: String, Codable, CaseIterable, Sendable {
    case height, weight, chest, waist, hips, inseam, sleeve
}

public enum MeasurementSource: String, Codable, Sendable {
    case entered, estimated
}

/// Stored in metric: centimetres for lengths, kilograms for weight.
public struct Measurement: Codable, Hashable, Sendable {
    public var value: Double
    public var source: MeasurementSource
    public var updatedAt: Date

    public init(value: Double, source: MeasurementSource = .entered, updatedAt: Date = .now) {
        self.value = value
        self.source = source
        self.updatedAt = updatedAt
    }
}

public struct BodyProfile: Codable, Hashable, Sendable {
    public var name: String
    public var measurements: [MeasurementKind: Measurement]
    public var fitPreference: FitPreference
    public var collection: ShoppingCollection
    public var units: UnitSystem
    /// Bumped on every saved change; recommendations record the version they used.
    public var version: Int

    public init(
        name: String = "Guest",
        measurements: [MeasurementKind: Measurement] = [:],
        fitPreference: FitPreference = .regular,
        collection: ShoppingCollection = .all,
        units: UnitSystem = .metric,
        version: Int = 1
    ) {
        self.name = name
        self.measurements = measurements
        self.fitPreference = fitPreference
        self.collection = collection
        self.units = units
        self.version = version
    }

    public func value(_ kind: MeasurementKind) -> Double? {
        measurements[kind]?.value
    }
}
