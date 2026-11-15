import Foundation

public enum FitConfidence: String, Codable, Sendable {
    /// Enough evidence to select the size automatically.
    case confident
    /// Missing body or garment data: the user must confirm a size before checkout.
    case limited
}

public enum ComparisonBasis: String, Codable, Sendable {
    /// Body measurement against the garment's actual dimension.
    case garmentDimension
    /// Body measurement against the brand's body-size chart range.
    case bodyChart
}

public struct FitComparison: Codable, Hashable, Sendable {
    public var kind: MeasurementKind
    public var basis: ComparisonBasis
    public var bodyValue: Double
    public var bodySource: MeasurementSource
    /// Garment dimension, or the midpoint of the body-chart range.
    public var referenceValue: Double
    /// referenceValue minus bodyValue, in centimetres.
    public var ease: Double
    /// One plain sentence, for example "10 cm of room around the chest."
    public var note: String

    public init(kind: MeasurementKind, basis: ComparisonBasis, bodyValue: Double, bodySource: MeasurementSource, referenceValue: Double, ease: Double, note: String) {
        self.kind = kind
        self.basis = basis
        self.bodyValue = bodyValue
        self.bodySource = bodySource
        self.referenceValue = referenceValue
        self.ease = ease
        self.note = note
    }
}

public struct SizeRecommendation: Codable, Hashable, Sendable {
    /// nil when no in-stock variant can be suggested at all.
    public var variantID: String?
    public var confidence: FitConfidence
    /// Short title, for example "A little room to move."
    public var headline: String
    /// One line, for example "Room through the chest; regular sleeve length."
    public var summary: String
    public var comparisons: [FitComparison]
    /// Measurements that would raise confidence if the user supplied them.
    public var missing: [MeasurementKind]
    public var profileVersion: Int
    public var rulesVersion: String

    public init(variantID: String?, confidence: FitConfidence, headline: String, summary: String, comparisons: [FitComparison] = [], missing: [MeasurementKind] = [], profileVersion: Int, rulesVersion: String = ShoppyCore.rulesVersion) {
        self.variantID = variantID
        self.confidence = confidence
        self.headline = headline
        self.summary = summary
        self.comparisons = comparisons
        self.missing = missing
        self.profileVersion = profileVersion
        self.rulesVersion = rulesVersion
    }
}

public enum SizingRules {
    /// Target chest ease in cm for a top, by fit preference.
    public static let topChestEase: [FitPreference: Double] = [.close: 6, .regular: 10, .relaxed: 16]
    /// Target waist ease in cm for pants measured on the garment.
    public static let pantWaistEase: [FitPreference: Double] = [.close: 0, .regular: 2, .relaxed: 5]
    /// Target hip ease in cm for pants measured on the garment.
    public static let pantHipEase: [FitPreference: Double] = [.close: 3, .regular: 6, .relaxed: 10]
    /// Stretch fabrics need less ease, in cm.
    public static let stretchReduction: [GarmentCategory: Double] = [.top: 3, .pants: 1]
    /// Where the body should sit inside a chart range, as an offset from the range midpoint in cm.
    public static let chartOffset: [FitPreference: Double] = [.close: -2, .regular: 0, .relaxed: 3]
    /// Weight of the hip comparison relative to the waist when ranking pants.
    public static let hipWeight = 0.5
    /// Missed target by more than this many cm and the headline asks the shopper to review the size.
    public static let reviewDeviation = 5.0
}

public enum SizingEngine {
    private struct Scored {
        var index: Int
        var variant: ProductVariant
        var score: Double
        var comparisons: [FitComparison]
    }

    public static func recommend(product: Product, profile: BodyProfile) -> SizeRecommendation {
        let key: MeasurementKind = product.category == .top ? .chest : .waist
        let inStock = product.variants.filter(\.inStock)
        guard !inStock.isEmpty else {
            return SizeRecommendation(
                variantID: nil, confidence: .limited, headline: "Currently unavailable.",
                summary: "Every size of this style is out of stock right now.",
                profileVersion: profile.version
            )
        }

        let helpful: [MeasurementKind] = product.category == .top ? [.chest] : [.waist, .hips, .inseam]
        let absent = helpful.filter { profile.value($0) == nil }
        let scored = product.variants.enumerated().compactMap { score(index: $0.offset, variant: $0.element, product: product, profile: profile) }

        guard profile.value(key) != nil, !scored.isEmpty else {
            let middle = inStock[inStock.count / 2]
            var lacking: [String] = []
            if profile.value(key) == nil { lacking.append("your \(key.rawValue)") }
            lacking += absent.filter { $0 != key }.map { "your \($0.rawValue)" }
            if scored.isEmpty { lacking.append("this garment's detailed measurements") }
            return SizeRecommendation(
                variantID: middle.id, confidence: .limited, headline: "Review your size.",
                summary: "We don't have \(join(lacking)).",
                missing: absent, profileVersion: profile.version
            )
        }

        let ranked = scored.sorted { $0.score != $1.score ? $0.score < $1.score : $0.index > $1.index }
        let best = ranked[0]
        let pick = ranked.first { $0.variant.inStock }!
        let primary = pick.comparisons.first { $0.kind == key }!

        var summary = summaryLine(product: product, comparisons: pick.comparisons, key: key)
        if pick.variant.id != best.variant.id {
            summary += " \(best.variant.sizeLabel) is out of stock, so this is the next closest size."
        }
        let off = pick.score > SizingRules.reviewDeviation
        return SizeRecommendation(
            variantID: pick.variant.id, confidence: .confident,
            headline: off ? "Review your size." : headline(category: product.category, ease: primary.ease, basis: primary.basis),
            summary: summary, comparisons: pick.comparisons, profileVersion: profile.version
        )
    }

    private static func score(index: Int, variant: ProductVariant, product: Product, profile: BodyProfile) -> Scored? {
        let preference = profile.fitPreference
        let reduction = product.hasStretch ? SizingRules.stretchReduction[product.category] ?? 0 : 0
        let kinds: [MeasurementKind] = product.category == .top ? [.chest, .sleeve] : [.waist, .hips, .inseam]
        var comparisons: [FitComparison] = []
        var total = 0.0
        for kind in kinds {
            guard let body = profile.measurements[kind] else { continue }
            if let reference = garmentValue(variant.garment, kind) {
                let ease = reference - body.value
                comparisons.append(FitComparison(kind: kind, basis: .garmentDimension, bodyValue: body.value, bodySource: body.source, referenceValue: reference, ease: ease, note: garmentNote(kind, ease)))
                switch kind {
                case .chest: total += abs(ease - ((SizingRules.topChestEase[preference] ?? 10) - reduction))
                case .waist: total += abs(ease - ((SizingRules.pantWaistEase[preference] ?? 2) - reduction))
                case .hips: total += SizingRules.hipWeight * abs(ease - ((SizingRules.pantHipEase[preference] ?? 6) - reduction))
                default: break
                }
            } else if let range = chartRange(variant.bodyChart, kind) {
                let mid = (range.min + range.max) / 2
                let ease = mid - body.value
                comparisons.append(FitComparison(kind: kind, basis: .bodyChart, bodyValue: body.value, bodySource: body.source, referenceValue: mid, ease: ease, note: chartNote(kind, body.value, range)))
                switch kind {
                case .chest, .waist: total += abs(ease - (SizingRules.chartOffset[preference] ?? 0))
                case .hips: total += SizingRules.hipWeight * abs(ease - (SizingRules.chartOffset[preference] ?? 0))
                default: break
                }
            }
        }
        let key: MeasurementKind = product.category == .top ? .chest : .waist
        guard comparisons.contains(where: { $0.kind == key }) else { return nil }
        return Scored(index: index, variant: variant, score: total, comparisons: comparisons)
    }

    private static func garmentValue(_ garment: GarmentDimensions?, _ kind: MeasurementKind) -> Double? {
        switch kind {
        case .chest: garment?.chest
        case .waist: garment?.waist
        case .hips: garment?.hips
        case .inseam: garment?.inseam
        case .sleeve: garment?.sleeve
        default: nil
        }
    }

    private static func chartRange(_ chart: BodyChart?, _ kind: MeasurementKind) -> SizeRange? {
        switch kind {
        case .chest: chart?.chest
        case .waist: chart?.waist
        case .hips: chart?.hips
        case .inseam: chart?.inseam
        default: nil
        }
    }

    private static func number(_ value: Double) -> String {
        let rounded = (value * 2).rounded() / 2
        return rounded == rounded.rounded() ? String(Int(rounded)) : String(format: "%.1f", rounded)
    }

    private static func area(_ kind: MeasurementKind) -> String {
        switch kind {
        case .chest: "around the chest"
        case .waist: "around the waist"
        case .hips: "around the hips"
        default: kind.rawValue
        }
    }

    private static func garmentNote(_ kind: MeasurementKind, _ ease: Double) -> String {
        let amount = number(abs(ease))
        switch kind {
        case .sleeve, .inseam:
            let name = kind.rawValue
            if abs(ease) < 1 { return "The \(name) is close to your measurement." }
            return ease > 0 ? "The \(name) runs \(amount) cm longer than yours." : "The \(name) runs \(amount) cm shorter than yours."
        default:
            if abs(ease) < 1 { return "Close to your \(kind.rawValue) measurement." }
            return ease > 0 ? "\(amount) cm of room \(area(kind))." : "\(amount) cm snugger than your \(kind.rawValue)."
        }
    }

    private static func chartNote(_ kind: MeasurementKind, _ body: Double, _ range: SizeRange) -> String {
        if body < range.min { return "Your \(kind.rawValue) is \(number(range.min - body)) cm below this size's range." }
        if body > range.max { return "Your \(kind.rawValue) is \(number(body - range.max)) cm above this size's range." }
        return "Your \(kind.rawValue) sits within this size's range."
    }

    private static func headline(category: GarmentCategory, ease: Double, basis: ComparisonBasis) -> String {
        if basis == .bodyChart { return "A true-to-size match." }
        switch category {
        case .top: return ease < 4 ? "A close fit." : ease < 13 ? "A little room to move." : "A relaxed fit."
        case .pants: return ease < 1 ? "A close fit." : ease < 5 ? "A comfortable fit." : "A relaxed fit."
        }
    }

    private static func summaryLine(product: Product, comparisons: [FitComparison], key: MeasurementKind) -> String {
        let primary = comparisons.first { $0.kind == key }!
        if primary.basis == .bodyChart {
            return "Your \(key.rawValue) sits in this size's chart range."
        }
        let ease = primary.ease
        var line: String
        if product.category == .top {
            line = ease < 4 ? "Snug through the chest" : ease < 8 ? "Close through the chest" : ease < 13 ? "Room through the chest" : "Generous room through the chest"
            if let sleeve = comparisons.first(where: { $0.kind == .sleeve }) {
                line += abs(sleeve.ease) <= 2 ? "; regular sleeve length." : sleeve.ease > 0 ? "; longer sleeve." : "; shorter sleeve."
            } else {
                line += "."
            }
        } else {
            line = ease < 1 ? "Close through the waist" : ease < 5 ? "Comfortable through the waist" : "Roomy through the waist"
            if let inseam = comparisons.first(where: { $0.kind == .inseam }) {
                line += abs(inseam.ease) <= 2 ? "; regular inseam." : inseam.ease > 0 ? "; longer inseam." : "; shorter inseam."
            } else {
                line += "."
            }
        }
        return line
    }

    private static func join(_ parts: [String]) -> String {
        switch parts.count {
        case 0: return "enough detail"
        case 1: return parts[0]
        case 2: return "\(parts[0]) or \(parts[1])"
        default: return parts.dropLast().joined(separator: ", ") + ", or " + parts.last!
        }
    }
}
