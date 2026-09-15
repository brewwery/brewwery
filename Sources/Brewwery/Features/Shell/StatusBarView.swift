import BrewweryCore
import SwiftUI

/// `components/layout/status-bar.tsx` — 34 pt, Homebrew state on the left, app version on
/// the right.
struct StatusBarView: View {
    @Environment(AppEnvironment.self) private var brewwery

    var body: some View {
        HStack(spacing: Metrics.cardSpacing) {
            HStack(spacing: Metrics.tightSpacing) {
                Circle()
                    .fill(brewwery.system.detection?.found == true ? BrewweryColor.success : BrewweryColor.warning)
                    .frame(width: 8, height: 8)
                Text(statusText)
            }

            Text(brewwery.system.info?.version ?? "unknown")
            Text(brewwery.system.info?.prefix ?? "No prefix detected")
            Text(brewwery.system.info?.architecture.rawValue ?? "unknown")
            Text("\(brewwery.library.formulae.count) formulae")
            Text("\(brewwery.library.casks.count) casks")

            Spacer(minLength: Metrics.rowSpacing)

            Text("\(AppInfo.name) \(AppInfo.version)")
        }
        .font(BrewweryFont.caption)
        .foregroundStyle(BrewweryColor.mutedForeground)
        .lineLimit(1)
        .padding(.horizontal, Metrics.cardSpacing)
        .frame(height: Metrics.statusBarHeight)
        .frame(maxWidth: .infinity)
        .background(BrewweryColor.titlebar)
    }

    private var statusText: String {
        if brewwery.system.isLoading { return "Loading Homebrew..." }
        return brewwery.system.detection?.found == true ? "Homebrew running" : "Homebrew not found"
    }
}
