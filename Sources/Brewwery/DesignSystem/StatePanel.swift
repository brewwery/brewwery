import BrewweryCore
import SwiftUI

/// `components/ui/state-panel.tsx` — the single card every page uses for its loading, empty,
/// error and "Homebrew not found" states, so those states look identical everywhere.
struct StatePanel<Description: View, Action: View>: View {
    enum Kind {
        case loading
        case empty
        case error
        case homebrew

        var systemImage: String {
            switch self {
            case .loading: "arrow.triangle.2.circlepath"
            case .empty: "shippingbox"
            case .error: "exclamationmark.triangle"
            case .homebrew: "mug"
            }
        }
    }

    let title: String
    var kind: Kind = .empty
    @ViewBuilder var description: Description
    @ViewBuilder var action: Action

    @State private var isSpinning = false

    var body: some View {
        BrewweryCard {
            VStack(spacing: 0) {
                Image(systemName: kind.systemImage)
                    .font(.system(size: 26, weight: .regular))
                    .foregroundStyle(BrewweryColor.accent)
                    .rotationEffect(.degrees(isSpinning ? 360 : 0))
                    .animation(
                        kind == .loading ? .linear(duration: 1).repeatForever(autoreverses: false) : .default,
                        value: isSpinning
                    )
                    .padding(.bottom, Metrics.cardSpacing)

                Text(title)
                    .font(BrewweryFont.cardTitle)
                    .foregroundStyle(BrewweryColor.foreground)
                    .multilineTextAlignment(.center)

                description
                    .font(BrewweryFont.body)
                    .foregroundStyle(BrewweryColor.mutedForeground)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .frame(maxWidth: 512)
                    .padding(.top, Metrics.tightSpacing)

                action.padding(.top, Metrics.cardSpacing)
            }
            .frame(maxWidth: .infinity, minHeight: 256)
        }
        .onAppear { isSpinning = kind == .loading }
    }
}

extension StatePanel where Description == EmptyView, Action == EmptyView {
    init(title: String, kind: Kind = .empty) {
        self.init(title: title, kind: kind, description: { EmptyView() }, action: { EmptyView() })
    }
}

extension StatePanel where Action == EmptyView {
    init(title: String, kind: Kind = .empty, @ViewBuilder description: () -> Description) {
        self.init(title: title, kind: kind, description: description, action: { EmptyView() })
    }
}

/// The "Homebrew not found" panel, repeated verbatim on every feature page in 0.9.7.
struct HomebrewNotFoundPanel: View {
    var body: some View {
        StatePanel(title: "Homebrew not found", kind: .homebrew) {
            VStack(spacing: 0) {
                Text("Brewwery could not find Homebrew at:")
                ForEach(HomebrewDetector.standardPaths, id: \.self) { path in
                    Text(path)
                        .font(BrewweryFont.monoCaption)
                        .foregroundStyle(BrewweryColor.foreground)
                        .padding(.top, path == HomebrewDetector.standardPaths.first ? Metrics.tightSpacing : 0)
                }
                Text("Install Homebrew or set a custom path in Settings.")
                    .padding(.top, Metrics.tightSpacing)
            }
        }
    }
}

/// `ErrorDescription` — the friendly line plus a disclosure carrying the code and raw text.
struct ErrorDescriptionView: View {
    let error: BrewweryError

    var body: some View {
        VStack(spacing: Metrics.tightSpacing) {
            Text(error.friendlyMessage)

            VStack(alignment: .leading, spacing: Metrics.tightSpacing) {
                Text(error.code.rawValue)
                    .font(BrewweryFont.monoCaption)
                    .foregroundStyle(BrewweryColor.warning)
                if let details = error.details {
                    MonospacedOutputView(text: details, maxHeight: 160)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .modifier(DisclosureWrapper())
        }
    }

    /// Wraps the details in the same "Show details" affordance the legacy `<details>` had.
    private struct DisclosureWrapper: ViewModifier {
        @State private var isExpanded = false

        func body(content: Content) -> some View {
            VStack(alignment: .leading, spacing: Metrics.tightSpacing) {
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) { isExpanded.toggle() }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 9, weight: .bold))
                        Text("Show details")
                    }
                    .font(BrewweryFont.captionEmphasis)
                    .foregroundStyle(BrewweryColor.accent)
                }
                .buttonStyle(.plain)

                if isExpanded { content }
            }
        }
    }
}

/// The inline error strip used inside dashboard cards and the Settings page.
struct InlineErrorView: View {
    let message: String

    var body: some View {
        Text(message)
            .font(BrewweryFont.body)
            .foregroundStyle(BrewweryColor.danger)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Metrics.rowSpacing)
            .background(BrewweryColor.dangerBackground)
            .clipShape(RoundedRectangle(cornerRadius: Metrics.controlRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Metrics.controlRadius, style: .continuous)
                    .strokeBorder(BrewweryColor.dangerBorder, lineWidth: 1)
            )
    }
}

/// A page heading: title and subtitle on the left; the page's own actions, the global search
/// field and the Settings button on the right.
///
/// The two global controls live here rather than in a title bar, so every screen shows them
/// in the same place, grouped after that page's actions and separated by a hairline.
struct PageHeader<Actions: View>: View {
    @Environment(AppEnvironment.self) private var brewwery

    let title: String
    var subtitle: String?
    /// When set, the header shows a filter for this page instead of the global search.
    var filter: Binding<String>?
    var filterPlaceholder = "Filter..."
    @ViewBuilder var actions: Actions

    /// The hairline only makes sense when there is something to separate the global
    /// controls from.
    private var hasActions: Bool { Actions.self != EmptyView.self }

    var body: some View {
        HStack(alignment: .top, spacing: Metrics.cardSpacing) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(BrewweryFont.pageTitle)
                    .foregroundStyle(BrewweryColor.foreground)
                if let subtitle {
                    Text(subtitle)
                        .font(BrewweryFont.body)
                        .foregroundStyle(BrewweryColor.mutedForeground)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: Metrics.tightSpacing)

            HStack(spacing: Metrics.tightSpacing) {
                actions

                if hasActions {
                    Rectangle()
                        .fill(BrewweryColor.border)
                        .frame(width: 1, height: 20)
                        .padding(.horizontal, 2)
                }

                if let filter {
                    HeaderFilterField(placeholder: filterPlaceholder, text: filter)
                } else {
                    GlobalSearchField()
                }
                SettingsButton()
            }
            // The controls keep their intrinsic width: a long subtitle wraps onto a second
            // line instead of squeezing "Check for updates" into "Check for up...".
            .fixedSize()
            .layoutPriority(1)
            // Nudged so the controls sit on the page title's optical centre rather than its
            // frame top.
            .padding(.top, 2)
        }
    }
}

extension PageHeader where Actions == EmptyView {
    init(title: String, subtitle: String? = nil, filter: Binding<String>? = nil, filterPlaceholder: String = "Filter...") {
        self.init(title: title, subtitle: subtitle, filter: filter, filterPlaceholder: filterPlaceholder, actions: { EmptyView() })
    }
}
