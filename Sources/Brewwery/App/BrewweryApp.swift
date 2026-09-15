import AppKit
import BrewweryCore
import SwiftUI

@main
struct BrewweryApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var environment = AppEnvironment()

    var body: some Scene {
        Window(AppInfo.name, id: "main") {
            RootView()
                .environment(environment)
                .preferredColorScheme(environment.settings.theme.colorScheme)
                .frame(
                    minWidth: Metrics.minimumWindowSize.width,
                    minHeight: Metrics.minimumWindowSize.height
                )
                .task {
                    appDelegate.configure(with: environment)
                    await environment.prepare()
                }
        }
        .defaultSize(Metrics.defaultWindowSize)
        // `titleBarStyle: "hiddenInset"` in the legacy window options.
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unifiedCompact)
        .commands { AppCommands(environment: environment) }
    }
}

extension AppTheme {
    /// `system` follows macOS; the other two force an appearance, as the legacy
    /// `data-theme` attribute did.
    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .dark: .dark
        case .light: .light
        }
    }
}
