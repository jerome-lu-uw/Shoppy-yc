import SwiftUI

/// Small uppercase label above a title or inside a card, for example "YOUR EDIT".
struct Eyebrow: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text.uppercased())
            .font(.caption)
            .tracking(0.6)
            .foregroundStyle(Theme.muted)
    }
}

/// Standard screen layout: ivory background, eyebrow and large title, scrolling content, and a pinned footer.
struct ShoppyScreen<Trailing: View, Content: View, Footer: View>: View {
    let eyebrow: String?
    let title: String
    @ViewBuilder var trailing: Trailing
    @ViewBuilder var content: Content
    @ViewBuilder var footer: Footer

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.spacing) {
                HStack(alignment: .firstTextBaseline) {
                    if let eyebrow {
                        Eyebrow(eyebrow)
                    }
                    Spacer()
                    trailing
                }
                Text(title)
                    .font(.largeTitle.bold())
                    .foregroundStyle(Theme.ink)
                    .padding(.bottom, 8)
                    .accessibilityAddTraits(.isHeader)
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Theme.margin)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .background(Theme.ivory.ignoresSafeArea())
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 8) {
                footer
            }
            .padding(.horizontal, Theme.margin)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
        }
        .toolbar(.hidden, for: .navigationBar)
    }
}

extension ShoppyScreen where Trailing == EmptyView {
    init(eyebrow: String?, title: String, @ViewBuilder content: () -> Content, @ViewBuilder footer: () -> Footer) {
        self.init(eyebrow: eyebrow, title: title, trailing: { EmptyView() }, content: content, footer: footer)
    }
}

extension ShoppyScreen where Trailing == EmptyView, Footer == EmptyView {
    init(eyebrow: String?, title: String, @ViewBuilder content: () -> Content) {
        self.init(eyebrow: eyebrow, title: title, trailing: { EmptyView() }, content: content, footer: { EmptyView() })
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(isEnabled ? Theme.onInk : Theme.muted)
            .frame(maxWidth: .infinity, minHeight: Theme.buttonHeight)
            .background(isEnabled ? Theme.ink : Theme.line, in: .capsule)
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    var isDestructive = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(isDestructive ? Theme.error : Theme.ink)
            .frame(maxWidth: .infinity, minHeight: Theme.buttonHeight)
            .background(Theme.card, in: .capsule)
            .overlay(Capsule().stroke(Theme.line))
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}

struct LinkButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.medium))
            .foregroundStyle(Theme.ink)
            .frame(maxWidth: .infinity, minHeight: 36)
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}

extension ButtonStyle where Self == PrimaryButtonStyle {
    static var shoppyPrimary: PrimaryButtonStyle { PrimaryButtonStyle() }
}

extension ButtonStyle where Self == SecondaryButtonStyle {
    static var shoppySecondary: SecondaryButtonStyle { SecondaryButtonStyle() }
    static var shoppyDestructive: SecondaryButtonStyle { SecondaryButtonStyle(isDestructive: true) }
}

extension ButtonStyle where Self == LinkButtonStyle {
    static var shoppyLink: LinkButtonStyle { LinkButtonStyle() }
}

extension View {
    /// White rounded card used for every grouped block.
    func shoppyCard(padding: CGFloat = Theme.cardPadding, fill: Color = Theme.card) -> some View {
        self
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(fill, in: .rect(cornerRadius: Theme.cardRadius))
    }
}

/// Pale banner such as "Demo bag — no real purchase".
struct InfoBanner: View {
    let text: String
    var fill: Color = Theme.banner

    init(_ text: String, fill: Color = Theme.banner) {
        self.text = text
        self.fill = fill
    }

    var body: some View {
        Text(text)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Theme.ink)
            .shoppyCard(fill: fill)
    }
}

/// Card row with a title, an optional value, and an optional chevron, such as "Fit preference · Regular ›".
struct RowCard: View {
    let title: String
    var value: String?
    var showsChevron = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .foregroundStyle(Theme.ink)
                Spacer()
                if let value {
                    Text(value)
                        .fontWeight(.medium)
                        .foregroundStyle(Theme.ink)
                }
                if showsChevron {
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Theme.ink)
                }
            }
            .shoppyCard()
        }
        .buttonStyle(.plain)
    }
}

/// The studio-toned segmented control from the design frames.
struct PillSegmented<Value: Hashable>: View {
    let options: [(value: Value, label: String)]
    @Binding var selection: Value

    var body: some View {
        HStack(spacing: 0) {
            ForEach(options, id: \.value) { option in
                Button {
                    selection = option.value
                } label: {
                    Text(option.label)
                        .font(.subheadline.weight(selection == option.value ? .semibold : .regular))
                        .foregroundStyle(Theme.ink)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(selection == option.value ? Theme.card : .clear, in: .rect(cornerRadius: 14))
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selection == option.value ? .isSelected : [])
            }
        }
        .padding(4)
        .background(Theme.studio, in: .rect(cornerRadius: Theme.cardRadius))
    }
}

/// Full-screen message state such as "Ready for a good find."
struct MessageState<Footer: View>: View {
    let eyebrow: String
    let title: String
    let message: String
    @ViewBuilder var footer: Footer

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Eyebrow(eyebrow)
            Spacer()
            Text(title)
                .font(.largeTitle.bold())
                .foregroundStyle(Theme.ink)
            Text(message)
                .foregroundStyle(Theme.muted)
            Spacer()
            Spacer()
            VStack(spacing: 8) {
                footer
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Theme.margin)
        .padding(.vertical, 12)
        .background(Theme.ivory.ignoresSafeArea())
    }
}

extension Int {
    /// Formats cents as whole dollars when possible: 6800 becomes "$68".
    var asPrice: String {
        self % 100 == 0 ? "$\(self / 100)" : String(format: "$%.2f", Double(self) / 100)
    }
}
