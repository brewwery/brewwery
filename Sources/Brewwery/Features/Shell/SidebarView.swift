import BrewweryCore
import SwiftUI

/// `components/layout/sidebar.tsx` — logo, three labelled sections, and a Homebrew status
/// card pinned to the bottom.
struct SidebarView: View {
    @Environment(AppEnvironment.self) private var brewwery
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            wordmark
            // The navigation scrolls so the sidebar never forces the window taller than the
            // 680 pt minimum the legacy window used; the status card stays pinned below it.
            ScrollView {
                navigation.padding(.bottom, Metrics.cardSpacing)
            }
            .scrollBounceBehavior(.basedOnSize)
            .frame(maxHeight: .infinity)

            homebrewCard
        }
        .padding(Metrics.cardSpacing)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(BrewweryColor.sidebar)
    }

    private var wordmark: some View {
        HStack(spacing: Metrics.tightSpacing) {
            if let image = AppAssets.wordmark(isDark: colorScheme == .dark) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 210, maxHeight: 48, alignment: .leading)
            } else {
                Image(systemName: "mug.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(BrewweryColor.accent)
                Text(AppInfo.name)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(BrewweryColor.foreground)
            }
        }
        .frame(height: 48, alignment: .leading)
        .padding(.bottom, Metrics.contentPadding)
        .accessibilityLabel(AppInfo.name)
    }

    private var navigation: some View {
        VStack(alignment: .leading, spacing: Metrics.cardSpacing) {
            ForEach(Page.sections) { section in
                VStack(alignment: .leading, spacing: 2) {
                    Text(section.title.uppercased())
                        .font(BrewweryFont.sidebarSection)
                        .tracking(0.88)
                        .foregroundStyle(BrewweryColor.mutedForeground)
                        .padding(.horizontal, Metrics.tightSpacing)
                        .padding(.bottom, 4)

                    ForEach(section.pages) { page in
                        SidebarItem(
                            page: page,
                            isSelected: brewwery.state.page == page,
                            badge: page == .updates ? brewwery.updates.count : 0
                        ) {
                            brewwery.state.select(page)
                        }
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Navigation")
    }

    private var homebrewCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: Metrics.tightSpacing) {
                Image(systemName: "shippingbox.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(BrewweryColor.accent)
                Text("Homebrew")
                    .font(BrewweryFont.captionEmphasis)
                    .foregroundStyle(BrewweryColor.foreground)
            }

            Text(statusDetail)
                .font(BrewweryFont.caption)
                .foregroundStyle(BrewweryColor.mutedForeground)
                .lineLimit(1)

            Text(brewwery.system.detection?.found == true ? "Detected" : "Not detected")
                .font(BrewweryFont.caption)
                .foregroundStyle(
                    brewwery.system.detection?.found == true ? BrewweryColor.success : BrewweryColor.warning
                )
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Metrics.rowSpacing)
        .background(BrewweryColor.card)
        .clipShape(RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous)
                .strokeBorder(BrewweryColor.border, lineWidth: 1)
        )
    }

    private var statusDetail: String {
        if brewwery.system.isLoading { return "Loading Homebrew..." }
        return brewwery.system.info?.version ?? "Homebrew not found"
    }
}

private struct SidebarItem: View {
    /// 32 pt rather than the 36 pt of other controls, so all fifteen destinations fit above
    /// the Homebrew card at the default window height without scrolling.
    static let rowHeight: CGFloat = 32

    let page: Page
    let isSelected: Bool
    /// Outdated packages, on the Updates row only. Zero renders nothing.
    let badge: Int
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: Metrics.rowSpacing) {
                Image(systemName: page.systemImage)
                    .font(.system(size: 14))
                    .frame(width: 16)
                Text(page.title)
                    .font(BrewweryFont.body)
                Spacer(minLength: 0)
                if badge > 0 {
                    Text("\(badge)")
                        .font(BrewweryFont.caption)
                        .monospacedDigit()
                        .foregroundStyle(BrewweryColor.background)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(BrewweryColor.accent, in: Capsule())
                        .accessibilityLabel("\(badge) updates available")
                }
            }
            .foregroundStyle(foreground)
            .padding(.horizontal, Metrics.tightSpacing)
            .frame(height: SidebarItem.rowHeight)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: Metrics.controlRadius, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    private var foreground: Color {
        if isSelected { return BrewweryColor.accent }
        return isHovering ? BrewweryColor.foreground : BrewweryColor.mutedForeground
    }

    private var background: Color {
        if isSelected { return BrewweryColor.accentSoft }
        return isHovering ? BrewweryColor.cardHover : .clear
    }
}
