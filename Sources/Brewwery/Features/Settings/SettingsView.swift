import BrewweryCore
import SwiftUI

/// `pages/settings.tsx` — Homebrew configuration, appearance, history and About.
///
/// Kept as an in-app page rather than a `Settings` scene because that is where 0.9.7 put
/// every one of these controls, including ones that are not preferences at all (path
/// validation, history export, diagnostics). ⌘, selects this page.
struct SettingsView: View {
    @Environment(AppEnvironment.self) private var brewwery

    @State private var pathValidation: BrewPathValidationResult?
    @State private var pathError: BrewweryError?
    @State private var isValidatingPath = false
    @State private var confirmation: ConfirmationRequest?

    private var settings: SettingsStore { brewwery.settings }
    private var system: SystemModel { brewwery.system }

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.sectionSpacing) {
            PageHeader(title: "Settings", subtitle: "Local preferences and app information.")

            homebrewCard
            appearanceCard
            dockCard
            updatesCard
            historyCard
            aboutCard
        }
        .confirmation($confirmation) { _ in
            Task {
                await brewwery.refreshHomebrewMetadata()
                await system.load()
            }
        }
    }

    // MARK: - Homebrew

    private var homebrewCard: some View {
        BrewweryHeaderCard {
            Text("Homebrew").font(BrewweryFont.controlLabel)
        } content: {
            VStack(alignment: .leading, spacing: Metrics.cardSpacing) {
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: Metrics.rowSpacing), count: 2),
                    spacing: Metrics.rowSpacing
                ) {
                    InfoBox(label: "Status", value: system.isLoading ? "Checking..." : (system.detection?.found == true ? "Detected" : "Not found"))
                    InfoBox(label: "Executable path", value: system.info?.path ?? system.detection?.path ?? "Auto-detect")
                    InfoBox(label: "Version", value: system.info?.version ?? "Unknown")
                    InfoBox(label: "Prefix", value: system.info?.prefix ?? "Unknown")
                    InfoBox(label: "Architecture", value: system.info?.architecture.rawValue ?? "Unknown")
                    InfoBox(
                        label: "Checked paths",
                        value: (system.detection?.checkedPaths ?? HomebrewDetector.standardPaths).joined(separator: ", ")
                    )
                }

                if let error = system.error {
                    InlineErrorView(message: error.message)
                }

                customPathSection

                HStack(spacing: Metrics.tightSpacing) {
                    ActionButton(title: "Refresh data", systemImage: "arrow.clockwise", isBusy: system.isLoading) {
                        Task { await system.load() }
                    }
                    .disabled(system.isLoading)

                    ActionButton(title: "Check Homebrew", systemImage: "arrow.triangle.2.circlepath") {
                        confirmation = ConfirmationRequest(
                            title: "Check Homebrew for updates?",
                            message: "Brewwery will run",
                            command: "brew update",
                            note: "Brewwery will then refresh Homebrew information. This may use the network and can take a little while.",
                            confirmLabel: "Check Homebrew"
                        )
                    }
                    .disabled(system.isLoading || brewwery.operations.isRunning || system.isHomebrewMissing)
                }
            }
        }
    }

    private var customPathSection: some View {
        VStack(alignment: .leading, spacing: Metrics.tightSpacing) {
            HStack(spacing: Metrics.tightSpacing) {
                Text("Custom Homebrew path")
                    .font(BrewweryFont.controlLabel)
                    .foregroundStyle(BrewweryColor.foreground)
                if settings.customHomebrewPath.isEmpty {
                    BrewweryBadge(text: "Auto-detect")
                } else {
                    BrewweryBadge(text: "Custom", tone: .warning)
                }
            }

            HStack(spacing: Metrics.tightSpacing) {
                BrewweryTextField(
                    placeholder: "/opt/homebrew/bin/brew",
                    text: Binding(
                        get: { settings.customHomebrewPath },
                        set: { settings.customHomebrewPath = $0 }
                    )
                )

                Button("Validate") { Task { await validatePath() } }
                    .brewweryButton()
                    .disabled(isValidatingPath || settings.customHomebrewPath.trimmingCharacters(in: .whitespaces).isEmpty)

                ActionButton(title: "Save", systemImage: "square.and.arrow.down", variant: .primary) {
                    Task { await savePath() }
                }
                .disabled(isValidatingPath || settings.customHomebrewPath.trimmingCharacters(in: .whitespaces).isEmpty)

                ActionButton(title: "Reset", systemImage: "arrow.uturn.backward") {
                    Task { await resetPath() }
                }
                .disabled(isValidatingPath)
            }

            if pathValidation?.valid == true, let validation = pathValidation {
                Text("Validated \(validation.version ?? "Homebrew") at \(validation.path).")
                    .font(BrewweryFont.caption)
                    .foregroundStyle(BrewweryColor.success)
            }

            if let pathError {
                Text(pathError.message)
                    .font(BrewweryFont.caption)
                    .foregroundStyle(BrewweryColor.danger)
            }

            Text("Saved paths are validated before use and applied to every Homebrew command, including streaming progress operations.")
                .font(BrewweryFont.caption)
                .foregroundStyle(BrewweryColor.mutedForeground)
        }
    }

    // MARK: - Appearance, updates, history, about

    private var appearanceCard: some View {
        BrewweryHeaderCard {
            Text("Appearance").font(BrewweryFont.controlLabel)
        } content: {
            VStack(alignment: .leading, spacing: Metrics.rowSpacing) {
                HStack(spacing: Metrics.tightSpacing) {
                    ForEach(AppTheme.allCases) { option in
                        Button(option.displayName) { settings.theme = option }
                            .brewweryButton(settings.theme == option ? .primary : .secondary)
                            .accessibilityAddTraits(settings.theme == option ? [.isSelected] : [])
                    }
                }
                Text("System follows macOS appearance. Light uses a warm macOS utility palette.")
                    .font(BrewweryFont.caption)
                    .foregroundStyle(BrewweryColor.mutedForeground)
            }
        }
    }

    /// Application updates, kept visually and functionally separate from Homebrew updates.
    /// The Dock badge counts *Homebrew* updates, so it belongs next to the Homebrew
    /// settings rather than in "Application updates" — and it can be switched off.
    private var dockCard: some View {
        BrewweryHeaderCard {
            Text("Dock").font(BrewweryFont.controlLabel)
        } content: {
            VStack(alignment: .leading, spacing: Metrics.rowSpacing) {
                Toggle(
                    "Show outdated package count on the Dock icon",
                    isOn: Binding(
                        get: { settings.showDockBadge },
                        set: { settings.showDockBadge = $0 }
                    )
                )
                .toggleStyle(.switch)
                .font(BrewweryFont.body)

                Text(dockCaption)
                    .font(BrewweryFont.caption)
                    .foregroundStyle(BrewweryColor.mutedForeground)
            }
        }
    }

    private var dockCaption: String {
        let count = brewwery.updates.count
        let source = "The badge shows the same number as Updates in the sidebar, read from brew outdated in the background every 30 minutes."
        guard let checked = brewwery.updates.lastChecked else { return source }
        return "\(source) Currently \(count), checked at \(checked.formatted(date: .omitted, time: .standard))."
    }

    private var updatesCard: some View {
        BrewweryHeaderCard {
            Text("Application updates").font(BrewweryFont.controlLabel)
        } content: {
            VStack(alignment: .leading, spacing: Metrics.rowSpacing) {
                Toggle(
                    "Check for Brewwery updates automatically",
                    isOn: Binding(
                        get: { settings.automaticallyCheckForUpdates },
                        set: {
                            settings.automaticallyCheckForUpdates = $0
                            brewwery.updater.applyPreferences()
                        }
                    )
                )
                .toggleStyle(.switch)
                .font(BrewweryFont.body)

                Toggle(
                    "Include pre-release versions",
                    isOn: Binding(
                        get: { settings.showPrereleaseUpdates },
                        set: { settings.showPrereleaseUpdates = $0 }
                    )
                )
                .toggleStyle(.switch)
                .font(BrewweryFont.body)

                HStack(spacing: Metrics.tightSpacing) {
                    ActionButton(title: "Check for updates now", systemImage: "arrow.down.circle") {
                        brewwery.updater.checkForUpdates()
                    }
                    .disabled(!brewwery.updater.canCheckForUpdates)
                }

                if case .unavailable(let message) = brewwery.updater.status {
                    Text(message)
                        .font(BrewweryFont.caption)
                        .foregroundStyle(BrewweryColor.mutedForeground)
                }

                Text("Brewwery application updates are unrelated to Homebrew package updates.")
                    .font(BrewweryFont.caption)
                    .foregroundStyle(BrewweryColor.mutedForeground)
            }
        }
    }

    private var historyCard: some View {
        BrewweryHeaderCard {
            Text("History").font(BrewweryFont.controlLabel)
        } content: {
            VStack(alignment: .leading, spacing: Metrics.tightSpacing) {
                HStack(spacing: Metrics.tightSpacing) {
                    Button("Export history JSON") { exportHistory() }
                        .brewweryButton()
                        .disabled(brewwery.history.entries.isEmpty)

                    ActionButton(title: "Clear history", systemImage: "trash") {
                        brewwery.history.clear()
                    }
                    .disabled(brewwery.history.entries.isEmpty)
                }

                Text("\(brewwery.history.entries.count) local operation entries stored on this Mac.")
                    .font(BrewweryFont.caption)
                    .foregroundStyle(BrewweryColor.mutedForeground)
            }
        }
    }

    private var aboutCard: some View {
        BrewweryHeaderCard {
            Text("About \(AppInfo.name)").font(BrewweryFont.controlLabel)
        } content: {
            VStack(alignment: .leading, spacing: Metrics.cardSpacing) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(AppInfo.name)
                        .font(BrewweryFont.sectionTitle)
                        .foregroundStyle(BrewweryColor.foreground)
                    Text(AppInfo.tagline)
                        .font(BrewweryFont.body)
                        .foregroundStyle(BrewweryColor.mutedForeground)
                }

                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: Metrics.rowSpacing), count: 2),
                    spacing: Metrics.rowSpacing
                ) {
                    InfoBox(label: "Version", value: AppInfo.version)
                    InfoBox(label: "Channel", value: AppInfo.channel)
                    InfoBox(label: "License", value: "MIT")
                    InfoBox(label: "Platform", value: "macOS first, Apple Silicon primary")
                }

                HStack(spacing: Metrics.tightSpacing) {
                    ActionButton(title: "Copy diagnostics", systemImage: "doc.on.clipboard", variant: .primary) {
                        Clipboard.copy(diagnosticsReport)
                    }
                    ExternalButton(label: "Brewwery site", url: AppInfo.websiteURL)
                    ExternalButton(label: "Release notes", url: AppInfo.releaseNotesURL)
                }
            }
        }
    }

    // MARK: - Actions

    /// Validation runs `brew --version`, so it is awaited on the client actor rather than
    /// blocking the main actor.
    private func validatePath() async {
        isValidatingPath = true
        pathError = nil
        defer { isValidatingPath = false }

        let result = await brewwery.client.validate(path: settings.customHomebrewPath)
        pathValidation = result
        pathError = result.error
    }

    private func savePath() async {
        isValidatingPath = true
        pathError = nil
        defer { isValidatingPath = false }

        let result = await brewwery.client.setCustomPath(settings.customHomebrewPath)
        pathValidation = result

        if result.valid {
            settings.customHomebrewPath = result.path
            await system.load()
            await brewwery.library.loadAll()
        } else {
            pathError = result.error
        }
    }

    private func resetPath() async {
        isValidatingPath = true
        pathError = nil
        defer { isValidatingPath = false }

        await brewwery.client.clearCustomPath()
        settings.resetCustomHomebrewPath()
        pathValidation = nil
        await system.load()
    }

    private func exportHistory() {
        guard let data = try? brewwery.history.exportData() else { return }
        let panel = NSSavePanel()
        panel.nameFieldStringValue = HistoryStore.exportFileName()
        guard panel.runModal() == .OK, let url = panel.url else { return }
        try? data.write(to: url, options: .atomic)
    }

    /// `diagnosticsText()` — app and Homebrew metadata plus local counts. No package
    /// history, and only ever written to the clipboard on an explicit click.
    private var diagnosticsReport: String {
        [
            "appVersion: \(AppInfo.version)",
            "channel: \(AppInfo.channel)",
            "brewVersion: \(system.info?.version ?? "unknown")",
            "brewPath: \(system.info?.path ?? "unknown")",
            "brewPrefix: \(system.info?.prefix ?? "unknown")",
            "architecture: \(system.info?.architecture.rawValue ?? "unknown")",
            "formulae: \(brewwery.library.formulae.count)",
            "casks: \(brewwery.library.casks.count)",
            "services: \(brewwery.services.services.count)",
            "updates: \(brewwery.updates.updates.count)"
        ].joined(separator: "\n")
    }
}

private struct ExternalButton: View {
    let label: String
    let url: String

    var body: some View {
        ActionButton(title: label, systemImage: "arrow.up.forward.square") {
            ExternalLink.open(url)
        }
    }
}
