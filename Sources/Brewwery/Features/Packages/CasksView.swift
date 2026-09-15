import BrewweryCore
import SwiftUI

/// `pages/casks.tsx` — installed casks. Same shape as Packages, without the leaf and
/// on-request filters, which have no cask equivalent.
struct CasksView: View {
    @Environment(AppEnvironment.self) private var brewwery

    @State private var query = ""
    @State private var sort: PackageSortKey = .name
    @State private var selection: Cask?
    @State private var confirmation: ConfirmationRequest?
    @State private var pendingUninstall: PackageReference?

    private var library: PackageLibrary { brewwery.library }
    private var rows: [Cask] { library.casks }

    private var visibleRows: [Cask] {
        let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        return rows
            .filter { cask in
                guard !normalized.isEmpty else { return true }
                return [cask.token, cask.name?.first, cask.description]
                    .compactMap { $0?.lowercased() }
                    .contains { $0.contains(normalized) }
            }
            .sorted { PackageSortKey.compare($0, $1, by: sort) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.sectionSpacing) {
            PageHeader(title: "Casks", subtitle: subtitle, filter: $query, filterPlaceholder: "Filter casks...") {
                ActionButton(title: "Refresh", systemImage: "arrow.clockwise", variant: .primary) {
                    Task { await refresh() }
                }
                .disabled(library.isLoadingCasks)
            }

            HStack(spacing: Metrics.rowSpacing) {
                BrewweryTabs(options: [(0, "All casks")], selection: .constant(0))
                Spacer(minLength: Metrics.tightSpacing)
                PackageSortControls(selection: $sort)
            }

            content
        }
        .task { if rows.isEmpty { await refresh() } }
        .overlay { drawer }
        .confirmation($confirmation) { _ in
            guard let reference = pendingUninstall else { return }
            Task { await uninstall(reference) }
        }
    }

    private var subtitle: String {
        library.isLoadingCasks ? "Loading packages..." : "\(visibleRows.count) of \(rows.count) installed casks"
    }

    @ViewBuilder
    private var content: some View {
        if library.isLoadingCasks {
            StatePanel(title: "Loading packages...", kind: .loading)
        } else if let error = library.casksError {
            if error.code == .homebrewNotFound {
                HomebrewNotFoundPanel()
            } else {
                StatePanel(
                    title: error.code == .brewJSONParseFailed ? "Failed to parse Homebrew output" : "Failed to load casks",
                    kind: .error
                ) {
                    ErrorDescriptionView(error: error)
                } action: {
                    Button("Retry") { Task { await refresh() } }.brewweryButton()
                }
            }
        } else {
            OperationProgressPanel()

            if rows.isEmpty {
                StatePanel(title: "No casks installed")
            } else if visibleRows.isEmpty {
                StatePanel(title: "No casks match your search")
            } else {
                table
            }
        }
    }

    private var table: some View {
        BrewweryTable(
            accessibilityLabel: "Installed casks",
            items: visibleRows,
            columns: [
                TableColumnSpec("Cask", width: .flexible(minimum: 180, weight: 1.35)) { cask in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: Metrics.tightSpacing) {
                            Text(cask.displayName)
                                .font(BrewweryFont.controlLabel)
                                .foregroundStyle(BrewweryColor.foreground)
                            if brewwery.favorites.isFavorite(name: cask.token, kind: .cask) {
                                Image(systemName: "star.fill")
                                    .font(.system(size: 10))
                                    .foregroundStyle(BrewweryColor.accent)
                            }
                        }
                        Text(cask.token)
                            .font(BrewweryFont.caption)
                            .foregroundStyle(BrewweryColor.mutedForeground)
                    }
                    .lineLimit(1)
                },
                TableColumnSpec("Version", width: .fixed(120)) { cask in
                    Text(cask.installedVersion ?? "Unknown")
                        .font(BrewweryFont.body)
                        .foregroundStyle(BrewweryColor.mutedForeground)
                        .lineLimit(1)
                },
                TableColumnSpec("Kind", width: .fixed(88)) { _ in
                    BrewweryBadge.kind(.cask)
                },
                TableColumnSpec("Description", width: .flexible(minimum: 180, weight: 2)) { cask in
                    Text(cask.description ?? "Installed Homebrew cask")
                        .font(BrewweryFont.body)
                        .foregroundStyle(BrewweryColor.mutedForeground)
                        .lineLimit(1)
                },
                TableColumnSpec("Status", width: .fixed(130)) { _ in
                    BrewweryBadge(text: "Installed", tone: .success)
                },
                TableColumnSpec("Actions", width: .fixed(64), alignment: .trailing) { cask in
                    IconButton("Actions for \(cask.displayName)", systemImage: "ellipsis", height: 28) {
                        selection = cask
                    }
                }
            ],
            maxHeight: 560,
            onActivate: { selection = $0 }
        )
    }

    @ViewBuilder
    private var drawer: some View {
        if let cask = selection {
            PackageDetailDrawer(
                detail: .cask(cask),
                isWorking: brewwery.operations.isRunning,
                onClose: { selection = nil },
                onUninstall: { reference in
                    pendingUninstall = reference
                    confirmation = .uninstall(reference)
                }
            )
        }
    }

    private func refresh() async {
        await library.loadCasks()
        await brewwery.system.load()
    }

    private func uninstall(_ reference: PackageReference) async {
        await brewwery.uninstallPackage(reference)
        pendingUninstall = nil
        selection = nil
        await refresh()
    }
}
