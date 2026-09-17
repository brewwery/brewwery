import BrewweryCore
import SwiftUI

/// `pages/updates.tsx`.
///
/// Three distinct actions that the UI keeps deliberately separate:
/// * **Refresh list** re-reads `brew outdated` — no network writes, no confirmation.
/// * **Check for updates** runs `brew update`, which refreshes Homebrew's *metadata* only.
/// * **Upgrade all / Upgrade** run `brew upgrade`, which changes installed packages.
struct UpdatesView: View {
    @Environment(AppEnvironment.self) private var brewwery

    private enum Pending: Equatable {
        case upgradeOne(PackageReference)
        case upgradeAll
        case metadata
    }

    @State private var confirmation: ConfirmationRequest?
    @State private var pending: Pending?

    private var updates: UpdatesModel { brewwery.updates }
    private var isBusy: Bool { updates.isLoading || brewwery.operations.isRunning }

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.sectionSpacing) {
            header
            summary
            content
        }
        .task { if updates.lastChecked == nil { await updates.refresh() } }
        .confirmation($confirmation, isWorking: brewwery.operations.isRunning) { _ in
            Task { await confirm() }
        }
    }

    private var header: some View {
        PageHeader(title: "Updates", subtitle: subtitle) {
            ActionButton(title: "Refresh list", systemImage: "arrow.clockwise") {
                Task { await updates.refresh() }
            }
            .disabled(isBusy)

            ActionButton(title: "Check for updates", systemImage: "arrow.triangle.2.circlepath") {
                pending = .metadata
                confirmation = ConfirmationRequest(
                    title: "Check for Homebrew updates?",
                    message: "Brewwery will run",
                    command: "brew update",
                    note: "Brewwery will then refresh outdated packages. This may use the network and can take a little while.",
                    confirmLabel: "Check for updates"
                )
            }
            .disabled(isBusy)

            ActionButton(title: "Upgrade all", systemImage: "arrow.down.circle", variant: .primary) {
                pending = .upgradeAll
                confirmation = ConfirmationRequest(
                    title: "Upgrade all packages?",
                    message: "Brewwery will run Homebrew's allowlisted upgrade command for all outdated packages.",
                    confirmLabel: "Upgrade"
                )
            }
            .disabled(isBusy || updates.updates.isEmpty)
        }
    }

    /// The Dock badge, the sidebar and the status bar all show `updates.count`, so the
    /// header names the command behind it and when it last ran. Kept to one short line —
    /// a long subtitle squeezes the actions on the right.
    private var subtitle: String {
        guard let checked = updates.lastChecked else {
            return "Check installed formulae and casks for updates."
        }
        let time = checked.formatted(date: .omitted, time: .shortened)
        let summary = updates.count == 0 ? "Up to date" : "\(updates.count) outdated"
        return "\(summary) · checked \(time)"
    }

    private var summary: some View {
        VStack(alignment: .leading, spacing: Metrics.rowSpacing) {
            HStack(spacing: Metrics.cardSpacing) {
                SummaryCard(label: "Total updates", value: updates.updates.count)
                SummaryCard(label: "Formulae", value: updates.formulaeCount)
                SummaryCard(label: "Casks", value: updates.casksCount)
            }

            // Answers "where is that number on the Dock coming from?" in the one place a
            // user goes looking for it.
            Text("The Dock badge, the sidebar and the status bar show this same total. Brewwery re-reads it in the background every 30 minutes and never upgrades anything on its own.")
                .font(BrewweryFont.caption)
                .foregroundStyle(BrewweryColor.mutedForeground)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private var content: some View {
        if updates.isLoading {
            StatePanel(title: "Loading updates...", kind: .loading)
        } else if let error = updates.error {
            if error.code == .homebrewNotFound {
                HomebrewNotFoundPanel()
            } else {
                StatePanel(
                    title: error.code == .updatesParseFailed ? "Failed to parse Homebrew updates" : "Failed to load updates",
                    kind: .error
                ) {
                    ErrorDescriptionView(error: error)
                } action: {
                    Button("Retry") { Task { await updates.refresh() } }.brewweryButton()
                }
            }
        } else {
            if updates.updates.isEmpty {
                StatePanel(title: "Everything is up to date")
            }

            OperationProgressPanel()

            if !updates.updates.isEmpty {
                table
            }
        }
    }

    private var table: some View {
        BrewweryTable(
            accessibilityLabel: "Outdated packages",
            items: updates.updates,
            columns: [
                TableColumnSpec("Package", width: .flexible(minimum: 180, weight: 2)) { update in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(update.name)
                            .font(BrewweryFont.controlLabel)
                            .foregroundStyle(BrewweryColor.foreground)
                        if update.installedVersions.count > 1 {
                            Text(update.installedVersions.joined(separator: ", "))
                                .font(BrewweryFont.caption)
                                .foregroundStyle(BrewweryColor.mutedForeground)
                        }
                    }
                    .lineLimit(1)
                },
                TableColumnSpec("Current", width: .fixed(144)) { update in
                    Text(update.currentVersion ?? update.installedVersions.first ?? "Unknown")
                        .font(BrewweryFont.body)
                        .foregroundStyle(BrewweryColor.mutedForeground)
                        .lineLimit(1)
                },
                TableColumnSpec("Latest", width: .fixed(144)) { update in
                    Text(update.latestVersion ?? "Unknown")
                        .font(BrewweryFont.body)
                        .foregroundStyle(BrewweryColor.foreground)
                        .lineLimit(1)
                },
                TableColumnSpec("Kind", width: .fixed(112)) { update in
                    BrewweryBadge.kind(update.kind)
                },
                TableColumnSpec("Status", width: .fixed(112)) { update in
                    BrewweryBadge(text: update.pinned == true ? "Pinned" : "Outdated", tone: .warning)
                },
                TableColumnSpec("Actions", width: .fixed(128), alignment: .trailing) { update in
                    Button("Upgrade") {
                        request(upgrade: update)
                    }
                    .brewweryButton(.secondary, height: Metrics.compactControlHeight)
                    .disabled(brewwery.operations.isRunning)
                }
            ],
            rowHeight: 64,
            maxHeight: 560,
            onActivate: { request(upgrade: $0) }
        )
    }

    private func request(upgrade update: OutdatedPackage) {
        let reference = PackageReference(name: update.name, kind: update.kind)
        pending = .upgradeOne(reference)
        confirmation = ConfirmationRequest(
            title: "Upgrade \(update.name)?",
            message: "Brewwery will run",
            command: HomebrewCommand.upgrade(reference).displayCommand(),
            confirmLabel: "Upgrade"
        )
    }

    private func confirm() async {
        switch pending {
        case .upgradeOne(let reference): await brewwery.upgradePackage(reference)
        case .upgradeAll: await brewwery.upgradeAllPackages()
        case .metadata: await brewwery.refreshHomebrewMetadata()
        case nil: break
        }
        pending = nil
    }
}
