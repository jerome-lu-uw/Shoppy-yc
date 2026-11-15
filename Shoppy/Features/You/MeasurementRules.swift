import Foundation
import ShoppyCore

/// Plausible ranges and text conversion shared by onboarding and the measurement editor.
enum MeasurementRules {
    enum Check: Equatable {
        case empty
        case valid(Double)
        case invalid
    }

    static let editableKinds: [MeasurementKind] = [.height, .weight, .chest, .waist, .hips, .inseam, .sleeve]

    static func metricRange(_ kind: MeasurementKind) -> ClosedRange<Double> {
        switch kind {
        case .height: 100...250
        case .weight: 30...250
        case .chest: 50...200
        case .waist: 40...200
        case .hips: 50...200
        case .inseam: 40...120
        case .sleeve: 40...110
        }
    }

    /// Reads what the user typed in the display unit and returns the metric value when it is in range.
    static func check(_ text: String, kind: MeasurementKind, units: UnitSystem) -> Check {
        let cleaned = text.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")
        guard !cleaned.isEmpty else { return .empty }
        guard let typed = Double(cleaned) else { return .invalid }
        let metric = Units.toMetric(typed, kind: kind, units: units)
        return metricRange(kind).contains((metric * 10).rounded() / 10) ? .valid(metric) : .invalid
    }

    /// The number alone, in the display unit, for a text field.
    static func text(forMetric metric: Double, kind: MeasurementKind, units: UnitSystem) -> String {
        let value = (Units.toDisplay(metric, kind: kind, units: units) * 10).rounded() / 10
        return value == value.rounded() ? String(Int(value)) : String(format: "%.1f", value)
    }

    /// Re-expresses typed text in another unit system. Text that is not a valid number is kept as typed.
    static func convert(_ text: String, kind: MeasurementKind, from: UnitSystem, to: UnitSystem) -> String {
        guard case .valid(let metric) = check(text, kind: kind, units: from) else { return text }
        return Self.text(forMetric: metric, kind: kind, units: to)
    }

    static func hint(_ kind: MeasurementKind, units: UnitSystem) -> String {
        let range = metricRange(kind)
        let low = text(forMetric: range.lowerBound, kind: kind, units: units)
        let high = text(forMetric: range.upperBound, kind: kind, units: units)
        return "\(kind.displayName) is usually between \(low) and \(high) \(Units.unitLabel(kind: kind, units: units))."
    }
}
