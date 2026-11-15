import SwiftUI
import ShoppyCore

/// "Measurements" editor. Presented as a sheet or pushed; saves through AppStore.updateProfile.
/// `focus` opens one row for editing straight away. `doneTitle` labels the button that leaves the saved state.
struct EditMeasurementsScreen: View {
    var focus: MeasurementKind?
    var doneTitle = "Back to You"

    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var units: UnitSystem
    @State private var values: [MeasurementKind: Double]
    @State private var editing: MeasurementKind?
    @State private var text = ""
    @State private var showsError = false
    @State private var saved = false

    init(focus: MeasurementKind? = nil, doneTitle: String = "Back to You") {
        self.focus = focus
        self.doneTitle = doneTitle
        _units = State(initialValue: .metric)
        _values = State(initialValue: [:])
    }

    var body: some View {
        Group {
            if saved {
                updatedState
            } else {
                editor
            }
        }
        .task {
            guard values.isEmpty, editing == nil else { return }
            units = store.profile.units
            values = store.profile.measurements.mapValues(\.value)
            if let focus { beginEditing(focus) }
        }
    }

    private var editor: some View {
        ShoppyScreen(eyebrow: "Your profile / Edit", title: "Measurements", trailing: { ExitButton(title: "Cancel") }) {
            PillSegmented(options: [(UnitSystem.metric, "Metric"), (.imperial, "Imperial")], selection: Binding(get: { units }, set: changeUnits))
            ForEach(MeasurementRules.editableKinds, id: \.self) { kind in
                if editing == kind {
                    editingRow(kind)
                } else {
                    row(kind)
                }
            }
            Text("We\u{2019}ll update your size suggestions. Items already in your bag will need a size review.")
                .font(.subheadline)
                .foregroundStyle(Theme.muted)
            Text("Your demo scan keeps its shape. Measurements change size suggestions only.")
                .font(.subheadline)
                .foregroundStyle(Theme.muted)
        } footer: {
            Button("Update size suggestions", action: save)
                .buttonStyle(.shoppyPrimary)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private var updatedState: some View {
        MessageState(
            eyebrow: "Sizing / Updated",
            title: "New details, fresh suggestions.",
            message: store.bagCount > 0
                ? "Your measurements are saved. Items already in your bag need a size review."
                : "Your measurements are saved. Size suggestions now use them."
        ) {
            if store.bagCount > 0 {
                Button("Review bag") {
                    store.selectedTab = .bag
                    dismiss()
                }
                .buttonStyle(.shoppyPrimary)
                Button(doneTitle) { dismiss() }
                    .buttonStyle(.shoppySecondary)
            } else {
                Button(doneTitle) { dismiss() }
                    .buttonStyle(.shoppyPrimary)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private func row(_ kind: MeasurementKind) -> some View {
        Button {
            guard commitEditing() else { return }
            beginEditing(kind)
        } label: {
            HStack {
                Text(kind.displayName)
                    .foregroundStyle(Theme.ink)
                Spacer()
                if let value = values[kind] {
                    Text("\(Units.format(value, kind: kind, units: units)) \u{00B7} \(source(of: kind, value: value))")
                        .fontWeight(.medium)
                        .foregroundStyle(Theme.ink)
                } else {
                    Text("Not provided")
                        .foregroundStyle(Theme.muted)
                }
            }
            .shoppyCard()
        }
        .buttonStyle(.plain)
        .accessibilityHint("Edit \(kind.displayName.lowercased())")
    }

    private func editingRow(_ kind: MeasurementKind) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            MeasurementField(kind: kind, label: kind.displayName, prompt: "Not provided", text: $text, units: units)
                .onSubmit { _ = commitEditing() }
            Button("Done") { _ = commitEditing() }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.ink)
                .frame(minHeight: 44)
        }
    }

    private func source(of kind: MeasurementKind, value: Double) -> String {
        guard let original = store.profile.measurements[kind], abs(original.value - value) < 0.05 else { return "Entered" }
        return original.source == .estimated ? "Estimated" : "Entered"
    }

    private func beginEditing(_ kind: MeasurementKind) {
        editing = kind
        text = values[kind].map { MeasurementRules.text(forMetric: $0, kind: kind, units: units) } ?? ""
    }

    /// Stores the open row's text. Returns false and keeps the row open when the value is out of range.
    private func commitEditing() -> Bool {
        guard let kind = editing else { return true }
        switch MeasurementRules.check(text, kind: kind, units: units) {
        case .valid(let metric): values[kind] = metric
        case .empty: values[kind] = nil
        case .invalid: return false
        }
        editing = nil
        return true
    }

    private func changeUnits(_ newUnits: UnitSystem) {
        if let kind = editing {
            text = MeasurementRules.convert(text, kind: kind, from: units, to: newUnits)
        }
        units = newUnits
    }

    private func save() {
        guard commitEditing() else { return }
        var profile = store.profile
        profile.units = units
        for kind in MeasurementRules.editableKinds {
            guard let value = values[kind] else {
                profile.measurements[kind] = nil
                continue
            }
            if let existing = profile.measurements[kind], abs(existing.value - value) < 0.05 { continue }
            profile.measurements[kind] = Measurement(value: value)
        }
        guard profile != store.profile else {
            dismiss()
            return
        }
        let sizingChanged = profile.measurements != store.profile.measurements
        store.updateProfile(profile)
        if sizingChanged {
            saved = true
        } else {
            dismiss()
        }
    }
}

#Preview {
    EditMeasurementsScreen()
        .environment(AppStore(persistent: false))
}
