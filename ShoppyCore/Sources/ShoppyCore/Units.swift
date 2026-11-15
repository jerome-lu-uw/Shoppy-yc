import Foundation

public extension MeasurementKind {
    var displayName: String {
        rawValue.capitalized
    }
}

/// Converts between stored metric values (cm, kg) and what the user sees.
public enum Units {
    public static let centimetresPerInch = 2.54
    public static let kilogramsPerPound = 0.45359237

    public static func unitLabel(kind: MeasurementKind, units: UnitSystem) -> String {
        switch (kind, units) {
        case (.weight, .metric): "kg"
        case (.weight, .imperial): "lb"
        case (_, .metric): "cm"
        case (_, .imperial): "in"
        }
    }

    public static func toDisplay(_ metricValue: Double, kind: MeasurementKind, units: UnitSystem) -> Double {
        guard units == .imperial else { return metricValue }
        return kind == .weight ? metricValue / kilogramsPerPound : metricValue / centimetresPerInch
    }

    public static func toMetric(_ displayValue: Double, kind: MeasurementKind, units: UnitSystem) -> Double {
        guard units == .imperial else { return displayValue }
        return kind == .weight ? displayValue * kilogramsPerPound : displayValue * centimetresPerInch
    }

    /// "178 cm", "75 kg", "5 ft 10 in", "165 lb", "38.5 in".
    public static func format(_ metricValue: Double, kind: MeasurementKind, units: UnitSystem) -> String {
        if kind == .height, units == .imperial {
            let totalInches = Int((metricValue / centimetresPerInch).rounded())
            return "\(totalInches / 12) ft \(totalInches % 12) in"
        }
        let value = toDisplay(metricValue, kind: kind, units: units)
        let rounded = units == .imperial && kind != .weight ? (value * 2).rounded() / 2 : value.rounded()
        let number = rounded == rounded.rounded() ? String(Int(rounded)) : String(format: "%.1f", rounded)
        return "\(number) \(unitLabel(kind: kind, units: units))"
    }
}
