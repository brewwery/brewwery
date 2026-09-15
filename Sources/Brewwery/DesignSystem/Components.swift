import BrewweryCore
import SwiftUI

// MARK: - Card

/// `components/ui/card.tsx` — rounded, bordered surface with the panel shadow.
struct BrewweryCard<Content: View>: View {
    var padding: CGFloat? = Metrics.cardSpacing
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding ?? 0)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(BrewweryColor.card)
            .clipShape(RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous)
                    .strokeBorder(BrewweryColor.border, lineWidth: 1)
            )
            .shadow(color: BrewweryColor.panelShadow, radius: 25, x: 0, y: 16)
    }
}

/// A card with the bordered header strip `CardHeader` provided.
struct BrewweryHeaderCard<Header: View, Content: View>: View {
    @ViewBuilder var header: Header
    @ViewBuilder var content: Content

    var body: some View {
        BrewweryCard(padding: nil) {
            VStack(alignment: .leading, spacing: 0) {
                header
                    .padding(.horizontal, Metrics.cardSpacing)
                    .padding(.vertical, Metrics.tightSpacing + 4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Divider().overlay(BrewweryColor.border)
                content
                    .padding(Metrics.cardSpacing)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

// MARK: - Badge

/// `components/ui/badge.tsx` plus the tinted variants the pages apply on top of it.
struct BrewweryBadge: View {
    enum Tone {
        case neutral
        case accent
        case success
        case warning
        case danger
        case cask
        case info

        var foreground: Color {
            switch self {
            case .neutral: BrewweryColor.mutedForeground
            case .accent, .warning: BrewweryColor.accent
            case .success: BrewweryColor.success
            case .danger: BrewweryColor.danger
            case .cask: BrewweryColor.caskAccent
            case .info: BrewweryColor.mutedForeground
            }
        }

        var background: Color {
            switch self {
            case .neutral, .info: BrewweryColor.card
            case .accent: BrewweryColor.accentSoft
            case .success: BrewweryColor.successBackground
            case .warning: BrewweryColor.warningBackground
            case .danger: BrewweryColor.dangerBackground
            case .cask: BrewweryColor.caskBackground
            }
        }

        var border: Color {
            switch self {
            case .neutral, .info: BrewweryColor.border
            case .accent: BrewweryColor.accent.opacity(0.3)
            case .success: BrewweryColor.successBorder
            case .warning: BrewweryColor.warningBorder
            case .danger: BrewweryColor.dangerBorder
            case .cask: BrewweryColor.caskBorder
            }
        }
    }

    let text: String
    var tone: Tone = .neutral
    var systemImage: String?

    var body: some View {
        HStack(spacing: 4) {
            if let systemImage {
                Image(systemName: systemImage).font(.system(size: 9, weight: .semibold))
            }
            Text(text)
        }
        .font(BrewweryFont.captionEmphasis)
        .foregroundStyle(tone.foreground)
        .lineLimit(1)
        .fixedSize()
        .padding(.horizontal, Metrics.tightSpacing)
        .padding(.vertical, 2)
        .background(tone.background, in: Capsule())
        .overlay(Capsule().strokeBorder(tone.border, lineWidth: 1))
    }
}

extension BrewweryBadge {
    /// Formula and cask badges are the most repeated pair in the UI.
    static func kind(_ kind: PackageKind) -> BrewweryBadge {
        BrewweryBadge(text: kind.rawValue, tone: kind == .cask ? .cask : .accent)
    }

    static func installed(_ installed: Bool) -> BrewweryBadge {
        BrewweryBadge(text: installed ? "Installed" : "Available", tone: installed ? .success : .neutral)
    }
}

// MARK: - Buttons

/// `components/ui/button.tsx` — primary / secondary / ghost, 36 pt tall, 6 pt radius.
struct BrewweryButtonStyle: ButtonStyle {
    enum Variant {
        case primary
        case secondary
        case ghost
    }

    var variant: Variant = .secondary
    var height: CGFloat = Metrics.controlHeight
    var fullWidth = false
    var alignment: Alignment = .center

    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovering = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(BrewweryFont.controlLabel)
            .foregroundStyle(foreground)
            .padding(.horizontal, Metrics.rowSpacing)
            .frame(height: height)
            .frame(maxWidth: fullWidth ? .infinity : nil, alignment: alignment)
            .background(background(pressed: configuration.isPressed))
            .clipShape(RoundedRectangle(cornerRadius: Metrics.controlRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Metrics.controlRadius, style: .continuous)
                    .strokeBorder(variant == .secondary ? BrewweryColor.border : .clear, lineWidth: 1)
            )
            .opacity(isEnabled ? 1 : 0.5)
            .contentShape(Rectangle())
            .onHover { isHovering = $0 }
            .animation(.easeOut(duration: 0.12), value: isHovering)
    }

    private var foreground: Color {
        switch variant {
        case .primary: BrewweryColor.accentForeground
        case .secondary: BrewweryColor.foreground
        case .ghost: isHovering ? BrewweryColor.foreground : BrewweryColor.mutedForeground
        }
    }

    private func background(pressed: Bool) -> Color {
        switch variant {
        case .primary:
            pressed || isHovering ? BrewweryColor.warning : BrewweryColor.accent
        case .secondary:
            pressed || isHovering ? BrewweryColor.cardHover : BrewweryColor.card
        case .ghost:
            pressed || isHovering ? BrewweryColor.cardHover : .clear
        }
    }
}

extension View {
    func brewweryButton(
        _ variant: BrewweryButtonStyle.Variant = .secondary,
        height: CGFloat = Metrics.controlHeight,
        fullWidth: Bool = false,
        alignment: Alignment = .center
    ) -> some View {
        buttonStyle(
            BrewweryButtonStyle(variant: variant, height: height, fullWidth: fullWidth, alignment: alignment)
        )
    }
}

/// A button whose label is an icon and a title, the shape used across every page header.
struct ActionButton: View {
    let title: String
    var systemImage: String?
    var variant: BrewweryButtonStyle.Variant = .secondary
    var height: CGFloat = Metrics.controlHeight
    var isBusy = false
    var fullWidth = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Metrics.tightSpacing) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 13, weight: .medium))
                        .rotationEffect(.degrees(isBusy ? 360 : 0))
                        .animation(
                            isBusy ? .linear(duration: 1).repeatForever(autoreverses: false) : .default,
                            value: isBusy
                        )
                }
                Text(title)
            }
        }
        .brewweryButton(variant, height: height, fullWidth: fullWidth, alignment: fullWidth ? .leading : .center)
    }
}

/// A button that shows only an icon.
///
/// The accessible name is a required argument, so an unlabeled icon button cannot be written:
/// VoiceOver reads `label`, and the same text appears as the hover tooltip. Every icon-only
/// control in the app goes through this type — `AccessibilityLintTests` enforces it.
struct IconButton: View {
    let label: String
    let systemImage: String
    var variant: BrewweryButtonStyle.Variant = .ghost
    var height: CGFloat = Metrics.controlHeight
    var tint: Color?
    let action: () -> Void

    init(
        _ label: String,
        systemImage: String,
        variant: BrewweryButtonStyle.Variant = .ghost,
        height: CGFloat = Metrics.controlHeight,
        tint: Color? = nil,
        action: @escaping () -> Void
    ) {
        self.label = label
        self.systemImage = systemImage
        self.variant = variant
        self.height = height
        self.tint = tint
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            if let tint {
                Image(systemName: systemImage).font(.system(size: 13)).foregroundStyle(tint)
            } else {
                Image(systemName: systemImage).font(.system(size: 13))
            }
        }
        .brewweryButton(variant, height: height)
        .help(label)
        .accessibilityLabel(label)
    }
}

// MARK: - Text field

/// `components/ui/input.tsx`.
struct BrewweryTextField: View {
    let placeholder: String
    @Binding var text: String
    var leadingSystemImage: String?
    var showsClearButton = false
    var onSubmit: (() -> Void)?
    /// Supplied when something outside the field needs to drive focus, such as ⌘K.
    var focus: FocusState<Bool>.Binding?

    @FocusState private var internalFocus: Bool

    private var isFocused: Bool { focus?.wrappedValue ?? internalFocus }

    var body: some View {
        HStack(spacing: Metrics.tightSpacing) {
            if let leadingSystemImage {
                Image(systemName: leadingSystemImage)
                    .font(.system(size: 13))
                    .foregroundStyle(BrewweryColor.mutedForeground)
            }
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(BrewweryFont.body)
                .foregroundStyle(BrewweryColor.foreground)
                .focused(focus ?? $internalFocus)
                .onSubmit { onSubmit?() }
            if showsClearButton, !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(BrewweryColor.mutedForeground)
                        .frame(width: 16, height: 16)
                        .background(BrewweryColor.muted, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, Metrics.rowSpacing)
        .frame(height: Metrics.controlHeight)
        .background(BrewweryColor.input)
        .clipShape(RoundedRectangle(cornerRadius: Metrics.controlRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Metrics.controlRadius, style: .continuous)
                .strokeBorder(isFocused ? BrewweryColor.warningBorder : BrewweryColor.border, lineWidth: 1)
        )
    }

}

// MARK: - Segmented tabs

/// `components/ui/tabs.tsx` — a bordered strip of pill buttons, not a system segmented
/// control, because the legacy tabs carry per-page labels and variable counts.
struct BrewweryTabs<Value: Hashable>: View {
    let options: [(value: Value, label: String)]
    @Binding var selection: Value

    var body: some View {
        HStack(spacing: 0) {
            ForEach(options, id: \.value) { option in
                Button {
                    selection = option.value
                } label: {
                    Text(option.label)
                        .font(BrewweryFont.body)
                        .foregroundStyle(
                            selection == option.value ? BrewweryColor.foreground : BrewweryColor.mutedForeground
                        )
                        .lineLimit(1)
                        .fixedSize()
                        .padding(.horizontal, Metrics.rowSpacing)
                        .padding(.vertical, 6)
                        .background(
                            selection == option.value ? BrewweryColor.cardHover : .clear,
                            in: RoundedRectangle(cornerRadius: 4, style: .continuous)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selection == option.value ? [.isSelected] : [])
            }
        }
        .padding(4)
        .background(BrewweryColor.input)
        .clipShape(RoundedRectangle(cornerRadius: Metrics.controlRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Metrics.controlRadius, style: .continuous)
                .strokeBorder(BrewweryColor.border, lineWidth: 1)
        )
    }
}

// MARK: - Disclosure

/// The `<details><summary>Show details</summary><pre>…</pre></details>` pattern the legacy
/// app used for raw command output and error details.
struct OutputDisclosure: View {
    let label: String
    let content: String
    var maxHeight: CGFloat = 280

    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.tightSpacing) {
            Button {
                withAnimation(.easeInOut(duration: 0.15)) { isExpanded.toggle() }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 9, weight: .bold))
                    Text(label)
                }
                .font(BrewweryFont.captionEmphasis)
                .foregroundStyle(BrewweryColor.accent)
            }
            .buttonStyle(.plain)

            if isExpanded {
                MonospacedOutputView(text: content, maxHeight: maxHeight)
            }
        }
    }
}

/// Selectable, monospaced command output on the `--brewwery-pre` surface.
struct MonospacedOutputView: View {
    let text: String
    var maxHeight: CGFloat = 280

    var body: some View {
        ScrollView {
            Text(text)
                .font(BrewweryFont.monoCaption)
                .foregroundStyle(BrewweryColor.mutedForeground)
                .lineSpacing(3)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(Metrics.rowSpacing)
        }
        .frame(maxHeight: maxHeight)
        .background(BrewweryColor.pre)
        .clipShape(RoundedRectangle(cornerRadius: Metrics.controlRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Metrics.controlRadius, style: .continuous)
                .strokeBorder(BrewweryColor.border, lineWidth: 1)
        )
    }
}

// MARK: - Labelled value

/// The bordered `label / value` box used on the Dashboard, Settings and the detail drawer.
struct InfoBox: View {
    let label: String
    let value: String
    var monospaced = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(BrewweryFont.caption)
                .foregroundStyle(BrewweryColor.mutedForeground)
            Text(value)
                .font(monospaced ? BrewweryFont.monoCaption : BrewweryFont.body)
                .foregroundStyle(BrewweryColor.foreground)
                .lineLimit(1)
                .truncationMode(.middle)
                .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Metrics.rowSpacing)
        .background(BrewweryColor.pre)
        .clipShape(RoundedRectangle(cornerRadius: Metrics.controlRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Metrics.controlRadius, style: .continuous)
                .strokeBorder(BrewweryColor.border, lineWidth: 1)
        )
    }
}

/// A summary tile: a caption over a large number. Used by Updates, Services and History.
struct SummaryCard: View {
    let label: String
    let value: String

    init(label: String, value: Int) {
        self.label = label
        self.value = String(value)
    }

    init(label: String, value: String) {
        self.label = label
        self.value = value
    }

    var body: some View {
        BrewweryCard {
            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(BrewweryFont.body)
                    .foregroundStyle(BrewweryColor.mutedForeground)
                Text(value)
                    .font(BrewweryFont.statValue)
                    .foregroundStyle(BrewweryColor.foreground)
            }
        }
    }
}
