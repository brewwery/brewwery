import AppKit

/// Images carried over from the legacy `desktop/assets` directory.
///
/// The wordmark ships in two variants because the original stylesheet swapped between two
/// SVGs: white ink on the dark theme, near-black ink on the warm light theme.
enum AppAssets {
    static let appIcon = image(named: "AppIcon")
    static let wordmarkDark = image(named: "WordmarkDark")
    static let wordmarkLight = image(named: "WordmarkLight")

    /// A template image, so macOS tints it for the menu bar's appearance automatically.
    static let menuBarIcon: NSImage? = {
        guard let image = image(named: "MenuBarIcon") else { return nil }
        image.isTemplate = true
        image.size = NSSize(width: 18, height: 18)
        return image
    }()

    static func wordmark(isDark: Bool) -> NSImage? {
        isDark ? wordmarkDark : wordmarkLight
    }

    /// The packaged app carries its images in `Contents/Resources`, where `Scripts/make-app.sh`
    /// copies them.
    ///
    /// SwiftPM's generated `Bundle.module` must not be touched in that case: it looks for a
    /// resource bundle beside the `.app` or at this machine's absolute build path, and calls
    /// `fatalError` when neither exists — which is every other Mac. It is only used when the
    /// executable runs unpackaged, from `swift run` or tests.
    private static func image(named name: String) -> NSImage? {
        if let url = Bundle.main.url(forResource: name, withExtension: "png") {
            return NSImage(contentsOf: url)
        }
        guard Bundle.main.bundleIdentifier != AppInfo.bundleIdentifier,
              let url = Bundle.module.url(forResource: name, withExtension: "png")
        else { return nil }
        return NSImage(contentsOf: url)
    }
}
