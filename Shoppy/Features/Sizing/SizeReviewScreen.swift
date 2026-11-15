import SwiftUI
import ShoppyCore

/// "Why we suggested M." / "Review your size." Presented as a sheet or pushed.
/// Calls onConfirm with the chosen variant, then dismisses itself.
struct SizeReviewScreen: View {
    let product: Product
    var currentVariantID: String?
    /// Lets previews and debug routes show the confident layout without the sizing engine.
    var recommendationOverride: SizeRecommendation?
    let onConfirm: (_ variantID: String, _ source: SizeSource) -> Void

    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var isChoosing = false
    @State private var selection: String?
    @State private var showsMeasurements = false

    var body: some View {
        let recommendation = recommendationOverride ?? store.recommendation(for: product)
        let suggested = recommendation.variantID.flatMap(product.variant)
        let current = (currentVariantID ?? recommendation.variantID).flatMap(product.variant)
        ShoppyScreen(eyebrow: "Sizing / \(product.brand)", title: title(recommendation, suggested: suggested), trailing: {
            Button("Close") { dismiss() }
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Theme.ink)
        }, content: {
            if isChoosing {
                chooser
            } else if recommendation.confidence == .confident {
                confident(recommendation)
            } else {
                limited(recommendation, current: current)
            }
        }, footer: {
            footer(recommendation, suggested: suggested, current: current)
        })
        .onAppear {
            selection = selection ?? current?.id
        }
        .sheet(isPresented: $showsMeasurements) {
            EditMeasurementsScreen()
        }
    }

    private func title(_ recommendation: SizeRecommendation, suggested: ProductVariant?) -> String {
        if isChoosing { return "Choose your size." }
        if recommendation.confidence == .confident, let suggested { return "Why we suggested \(suggested.sizeLabel)." }
        return "Review your size."
    }

    private func confirm(_ variantID: String, _ source: SizeSource) {
        onConfirm(variantID, source)
        dismiss()
    }

    // MARK: Confident

    @ViewBuilder
    private func confident(_ recommendation: SizeRecommendation) -> some View {
        let units = store.profile.units
        VStack(alignment: .leading, spacing: 4) {
            Text("Estimated fit").font(.subheadline.weight(.semibold))
            Text(recommendation.summary).foregroundStyle(Theme.muted)
        }
        .foregroundStyle(Theme.ink)
        .shoppyCard(fill: Theme.banner)

        Text(recommendation.headline)
            .font(.title2.bold())
            .foregroundStyle(Theme.ink)
            .padding(.top, 4)

        if !recommendation.comparisons.isEmpty {
            VStack(alignment: .leading, spacing: 16) {
                ForEach(recommendation.comparisons, id: \.kind) { comparison in
                    VStack(alignment: .leading, spacing: 6) {
                        Eyebrow("\(comparison.kind.displayName) circumference")
                        comparisonRow("You", Units.format(comparison.bodyValue, kind: comparison.kind, units: units), comparison.bodySource == .entered ? "entered" : "estimated")
                        comparisonRow("Garment", Units.format(comparison.referenceValue, kind: comparison.kind, units: units), comparison.basis == .garmentDimension ? "garment measurement" : "brand size chart")
                    }
                }
            }
            .shoppyCard()

            VStack(alignment: .leading, spacing: 4) {
                ForEach(recommendation.comparisons, id: \.kind) { comparison in
                    Text(comparison.note)
                }
            }
            .foregroundStyle(Theme.muted)
        }

        if !recommendation.missing.isEmpty {
            Text("More certain with your entered \(recommendation.missing.map { $0.rawValue }.joined(separator: ", ")). This is an estimate, not a guarantee.")
                .font(.subheadline)
                .foregroundStyle(Theme.muted)
        }

        fitPreferenceRow
    }

    private func comparisonRow(_ label: String, _ value: String, _ source: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label).foregroundStyle(Theme.muted)
            Spacer()
            Text(value).fontWeight(.semibold)
            Text("· \(source)").font(.footnote).foregroundStyle(Theme.muted)
        }
        .foregroundStyle(Theme.ink)
        .accessibilityElement(children: .combine)
    }

    private var fitPreferenceRow: some View {
        Menu {
            ForEach(FitPreference.allCases, id: \.self) { preference in
                Button {
                    var profile = store.profile
                    profile.fitPreference = preference
                    store.updateProfile(profile)
                } label: {
                    if preference == store.profile.fitPreference {
                        Label(preference.rawValue.capitalized, systemImage: "checkmark")
                    } else {
                        Text(preference.rawValue.capitalized)
                    }
                }
            }
        } label: {
            HStack {
                Text("Fit preference").foregroundStyle(Theme.ink)
                Spacer()
                Text(store.profile.fitPreference.rawValue.capitalized).fontWeight(.medium).foregroundStyle(Theme.ink)
                Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(Theme.ink)
            }
            .shoppyCard()
        }
    }

    // MARK: Limited

    @ViewBuilder
    private func limited(_ recommendation: SizeRecommendation, current: ProductVariant?) -> some View {
        if let current {
            Text("Selected \(current.sizeLabel)")
                .font(.title3.weight(.medium))
                .foregroundStyle(Theme.ink)
        }
        Text("Estimated fit · Limited data")
            .font(.headline)
            .foregroundStyle(Theme.warn)
        Text(recommendation.summary)
            .foregroundStyle(Theme.muted)
        Text("Review the size before adding it to your bag. Your selected size is always shown.")
            .foregroundStyle(Theme.muted)
        sizeList(product.variants.filter(\.inStock))
    }

    // MARK: Choose

    private var chooser: some View {
        VStack(alignment: .leading, spacing: Theme.spacing) {
            Text(product.name)
                .font(.title3.weight(.medium))
                .foregroundStyle(Theme.ink)
            Text("\(product.brand) · \(product.colorName) · \(product.priceCents.asPrice)")
                .foregroundStyle(Theme.muted)
            sizeList(product.variants)
        }
    }

    private func sizeList(_ variants: [ProductVariant]) -> some View {
        VStack(spacing: 8) {
            ForEach(variants) { variant in
                Button {
                    selection = variant.id
                } label: {
                    HStack {
                        Text("Size \(variant.sizeLabel)")
                        Spacer()
                        if !variant.inStock {
                            Text("Out of stock").font(.footnote)
                        } else if selection == variant.id {
                            Image(systemName: "checkmark").fontWeight(.semibold)
                        }
                    }
                    .foregroundStyle(variant.inStock ? Theme.ink : Theme.muted)
                    .shoppyCard()
                    .overlay {
                        RoundedRectangle(cornerRadius: Theme.cardRadius)
                            .stroke(Theme.ink, lineWidth: selection == variant.id && variant.inStock ? 2 : 0)
                    }
                }
                .buttonStyle(.plain)
                .disabled(!variant.inStock)
                .accessibilityAddTraits(selection == variant.id ? .isSelected : [])
            }
        }
    }

    // MARK: Footer

    @ViewBuilder
    private func footer(_ recommendation: SizeRecommendation, suggested: ProductVariant?, current: ProductVariant?) -> some View {
        if isChoosing || recommendation.confidence == .limited {
            if let chosen = selection.flatMap(product.variant), chosen.inStock {
                Button("Use \(chosen.sizeLabel)") { confirm(chosen.id, .userChosen) }
                    .buttonStyle(.shoppyPrimary)
            }
            if isChoosing {
                Button("Back") { isChoosing = false }
                    .buttonStyle(.shoppyLink)
            } else {
                Button("Improve my measurements") { showsMeasurements = true }
                    .buttonStyle(.shoppySecondary)
                Button("Choose another size") { isChoosing = true }
                    .buttonStyle(.shoppyLink)
            }
        } else {
            if let current {
                Button("Keep \(current.sizeLabel)") {
                    confirm(current.id, current.id == suggested?.id ? .suggested : .userChosen)
                }
                .buttonStyle(.shoppyPrimary)
            }
            Button("Improve my measurements") { showsMeasurements = true }
                .buttonStyle(.shoppySecondary)
            Button("Choose another size") { isChoosing = true }
                .buttonStyle(.shoppyLink)
        }
    }
}

#if DEBUG
#Preview("Confident") {
    let store = AppStore(persistent: false)
    return SizeReviewScreen(product: store.catalog[0], currentVariantID: nil) { _, _ in }
        .environment(store)
}
#endif
