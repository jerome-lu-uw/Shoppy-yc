import SwiftUI
import ShoppyCore

/// "Your edit": shopping collection, garments, and preferred fit.
struct DiscoverFiltersSheet: View {
    @Binding var garments: Set<GarmentCategory>

    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ShoppyScreen(eyebrow: "Discover / Filters", title: "Your edit") {
            HStack {
                Text("Shopping collection")
                    .font(.headline)
                    .foregroundStyle(Theme.ink)
                Spacer()
                Button("Reset") {
                    garments = Set(GarmentCategory.allCases)
                    update { $0.collection = .all; $0.fitPreference = .regular }
                }
                .font(.headline)
                .foregroundStyle(Theme.ink)
                .frame(minHeight: 44)
            }
            PillSegmented(
                options: [(ShoppingCollection.women, "Women"), (.men, "Men"), (.all, "All")],
                selection: Binding(get: { store.profile.collection }, set: { value in update { $0.collection = value } })
            )
            Eyebrow("Garments")
            HStack(spacing: 0) {
                garmentChip(.top, "Tops")
                garmentChip(.pants, "Pants")
            }
            .padding(4)
            .background(Theme.studio, in: .rect(cornerRadius: Theme.cardRadius))
            Eyebrow("Preferred fit")
            PillSegmented(
                options: [(FitPreference.close, "Close"), (.regular, "Regular"), (.relaxed, "Relaxed")],
                selection: Binding(get: { store.profile.fitPreference }, set: { value in update { $0.fitPreference = value } })
            )
        } footer: {
            EmptyView()
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 8) {
            Button("Show looks") { dismiss() }
                .buttonStyle(.shoppyPrimary)
            }
            .padding(.horizontal, Theme.margin)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(Theme.ivory)
        }
    }

    private func update(_ change: (inout BodyProfile) -> Void) {
        var profile = store.profile
        change(&profile)
        store.updateProfile(profile)
    }

    private func garmentChip(_ category: GarmentCategory, _ label: String) -> some View {
        let selected = garments.contains(category)
        return Button {
            if selected {
                if garments.count > 1 { garments.remove(category) }
            } else {
                garments.insert(category)
            }
        } label: {
            Label(label, systemImage: selected ? "checkmark" : "circle")
                .labelStyle(.titleAndIcon)
                .font(.subheadline.weight(selected ? .semibold : .regular))
                .foregroundStyle(Theme.ink)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(selected ? Theme.card : .clear, in: .rect(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
