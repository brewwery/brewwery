import SwiftUI

/// Layout constants ported from the legacy Tailwind classes, kept in one place so the
/// vertical rhythm of the original is reproducible rather than re-guessed per screen.
enum Metrics {
    /// `grid-cols-[260px_1fr]`
    static let sidebarWidth: CGFloat = 260
    /// `grid-rows-[48px_1fr_34px]`
    static let titlebarHeight: CGFloat = 48
    static let statusBarHeight: CGFloat = 34
    /// `p-6` on the content area.
    static let contentPadding: CGFloat = 24
    /// `space-y-5` between page sections.
    static let sectionSpacing: CGFloat = 20
    /// `gap-4`
    static let cardSpacing: CGFloat = 16
    /// `gap-3`
    static let rowSpacing: CGFloat = 12
    /// `gap-2`
    static let tightSpacing: CGFloat = 8
    /// `h-9` on buttons and inputs.
    static let controlHeight: CGFloat = 36
    /// `h-8` on the compact buttons used inside cards and table rows.
    static let compactControlHeight: CGFloat = 32
    /// `rounded-md`
    static let controlRadius: CGFloat = 6
    /// `rounded-lg`
    static let cardRadius: CGFloat = 8
    /// `px-4 py-3` inside table cells.
    static let tableCellPaddingHorizontal: CGFloat = 16
    static let tableCellPaddingVertical: CGFloat = 12
    /// `rowHeight = 76` in the virtualised tables.
    static let virtualizedRowHeight: CGFloat = 76
    /// `w-[420px]` detail drawer.
    static let drawerWidth: CGFloat = 420
    /// Window frame from `window.ts`.
    static let defaultWindowSize = CGSize(width: 1180, height: 920)
    static let minimumWindowSize = CGSize(width: 960, height: 680)
}

/// Type scale ported from the Tailwind classes in use.
///
/// The legacy CSS asked for Inter and fell back to the system UI font; natively that is San
/// Francisco, which is what the fallback resolved to on macOS anyway.
enum BrewweryFont {
    /// `text-2xl font-semibold` — page titles.
    static let pageTitle = Font.system(size: 24, weight: .semibold)
    /// `text-lg font-semibold`
    static let sectionTitle = Font.system(size: 18, weight: .semibold)
    /// `text-base font-semibold`
    static let cardTitle = Font.system(size: 16, weight: .semibold)
    /// `text-sm font-semibold`
    static let panelTitle = Font.system(size: 14, weight: .semibold)
    /// `text-sm font-medium`
    static let controlLabel = Font.system(size: 14, weight: .medium)
    /// `text-sm`
    static let body = Font.system(size: 14)
    /// `text-xs`
    static let caption = Font.system(size: 12)
    /// `text-xs font-medium`
    static let captionEmphasis = Font.system(size: 12, weight: .medium)
    /// `text-[11px] font-semibold uppercase tracking-[0.08em]` — sidebar section headers.
    static let sidebarSection = Font.system(size: 11, weight: .semibold)
    /// `text-2xl font-semibold` on stat values.
    static let statValue = Font.system(size: 24, weight: .semibold)
    /// `font-mono text-xs`
    static let monoCaption = Font.system(size: 12, design: .monospaced)
    /// `font-mono text-sm`
    static let mono = Font.system(size: 14, design: .monospaced)
}
