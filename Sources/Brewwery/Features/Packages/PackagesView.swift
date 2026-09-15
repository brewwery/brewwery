import BrewweryCore
import SwiftUI

/// `pages/packages.tsx` — installed formulae.
struct PackagesView: View {
    @Environment(AppEnvironment.self) private var brewwery

    enum Filter: String, CaseIterable {
        case all, leaves, request, dependency

        var label: String {
            switch self {
            case .all: "All formulae"
            case .leaves: "Leaves"
            case .request: "On request"
            case .dependency: "Dependencies"
            }
        }
    }

    @State private var query = ""
    @State private var filter: Filter = .all
    @State private var sort: PackageSortKey = .name
    @State private var selection: Formula?
    @State private var confirmation: ConfirmationRequest?
    @State private var pendingUninstall: PackageReference?

    private var library: PackageLibrary { brewwery.library }
    private var rows: [Formula] { library.formulae }

    private var visibleRows: [Formula] {
        let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        return rows
            .filter { formula in
                switch filter {
                case .request where formula.installedOnRequest != true: return false
                case .dependency where formula.installedOnRequest != false: return false
                case .leaves where !library.isLeaf(formula): return false
                default: break
                }
                guard !normalized.isEmpty else { return true }
                return [formula.name, formula.fullName, formula.description]
                    .compactMap { $0?.lowercased() }
                    .contains { $0.contains(normalized) }
            }
            .sorted { PackageSortKey.compare($0, $1, by: sort) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.sectionSpacing) {
            PageHeader(title: "Packages", subtitle: subtitle, filter: $query, filterPlaceholder: "Filter formulae...") {
                ActionButton(title: "Refresh", systemImage: "arrow.clockwise", variant: .primary) {
                    Task { await refresh() }
                }
                .disabled(library.isLoadingFormulae)
            }

            filterBar
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
        library.isLoadingFormulae
            ? "Loading packages..."
            : "\(visibleRows.count) of \(rows.count) installed formulae"
    }

    private var filterBar: some View {
        HStack(spacing: Metrics.rowSpacing) {
            BrewweryTabs(
                options: Filter.allCases.map { ($0, $0.label) },
                selection: $filter
            )
            Spacer(minLength: Metrics.tightSpacing)
            PackageSortControls(selection: $sort)
        }
    }

    @ViewBuilder
    private var content: some View {
        if library.isLoadingFormulae {
            StatePanel(title: "Loading packages...", kind: .loading)
        } else if let error = library.formulaeError {
            if error.code == .homebrewNotFound {
                HomebrewNotFoundPanel()
            } else {
                StatePanel(
                    title: error.code == .brewJSONParseFailed
                        ? "Failed to parse Homebrew output"
                        : "Failed to load formulae",
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
                StatePanel(title: "No formulae installed")
            } else if visibleRows.isEmpty {
                StatePanel(title: "No formulae match your search")
            } else {
                table
            }
        }
    }

    private var table: some View {
        BrewweryTable(
            accessibilityLabel: "Installed formulae",
            items: visibleRows,
            columns: [
                TableColumnSpec("Package", width: .flexible(minimum: 170, weight: 1.35)) { formula in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: Metrics.tightSpacing) {
                            Text(formula.name)
                                .font(BrewweryFont.controlLabel)
                                .foregroundStyle(BrewweryColor.foreground)
                            if brewwery.favorites.isFavorite(name: formula.name, kind: .formula) {
                                Image(systemName: "star.fill")
                                    .font(.system(size: 10))
                                    .foregroundStyle(BrewweryColor.accent)
                            }
                        }
                        Text(formula.fullName ?? formula.name)
                            .font(BrewweryFont.caption)
                            .foregroundStyle(BrewweryColor.mutedForeground)
                    }
                    .lineLimit(1)
                },
                TableColumnSpec("Version", width: .fixed(120)) { formula in
                    Text(formula.installedVersion ?? "Unknown")
                        .font(BrewweryFont.body)
                        .foregroundStyle(BrewweryColor.mutedForeground)
                        .lineLimit(1)
                },
                TableColumnSpec("Kind", width: .fixed(88)) { _ in
                    BrewweryBadge.kind(.formula)
                },
                TableColumnSpec("Description", width: .flexible(minimum: 180, weight: 2)) { formula in
                    Text(formula.description ?? "Installed Homebrew formula")
                        .font(BrewweryFont.body)
                        .foregroundStyle(BrewweryColor.mutedForeground)
                        .lineLimit(1)
                },
                TableColumnSpec("Status", width: .fixed(190)) { formula in
                    HStack(spacing: Metrics.tightSpacing) {
                        BrewweryBadge(text: "Installed", tone: .success)
                        if let onRequest = formula.installedOnRequest {
                            BrewweryBadge(text: onRequest ? "On request" : "Dependency")
                        }
                    }
                },
                TableColumnSpec("Actions", width: .fixed(64), alignment: .trailing) { formula in
                    IconButton("Actions for \(formula.name)", systemImage: "ellipsis", height: 28) {
                        selection = formula
                    }
                }
            ],
            maxHeight: 560,
            onActivate: { selection = $0 }
        )
    }

    @ViewBuilder
    private var drawer: some View {
        if let formula = selection {
            PackageDetailDrawer(
                detail: .formula(formula),
                isWorking: brewwery.operations.isRunning,
                onClose: { selection = nil },
                onUninstall: requestUninstall
            )
        }
    }

    private func requestUninstall(_ reference: PackageReference) {
        pendingUninstall = reference
        confirmation = .uninstall(reference)
    }

    private func refresh() async {
        await library.loadFormulae()
        await brewwery.system.load()
    }

    private func uninstall(_ reference: PackageReference) async {
        await brewwery.uninstallPackage(reference)
        pendingUninstall = nil
        selection = nil
        await refresh()
    }
}

// MARK: - Shared sorting

enum PackageSortKey: String, CaseIterable {
    case name, version, status

    var label: String { rawValue.capitalized }

    /// `compareFormula` — version sorting is numeric-aware, matching `localeCompare` with
    /// `{ numeric: true }`.
    static func compare(_ lhs: Formula, _ rhs: Formula, by key: PackageSortKey) -> Bool {
        switch key {
        case .version:
            (lhs.installedVersion ?? "").localizedStandardCompare(rhs.installedVersion ?? "") == .orderedAscending
        case .status:
            String(describing: rhs.installedOnRequest) < String(describing: lhs.installedOnRequest)
        case .name:
            lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        }
    }

    /// `compareCask` — casks have no on-request flag, so status falls back to the name.
    static func compare(_ lhs: Cask, _ rhs: Cask, by key: PackageSortKey) -> Bool {
        switch key {
        case .version:
            (lhs.installedVersion ?? "").localizedStandardCompare(rhs.installedVersion ?? "") == .orderedAscending
        case .name, .status:
            lhs.displayName.localizedStandardCompare(rhs.displayName) == .orderedAscending
        }
    }
}

struct PackageSortControls: View {
    @Binding var selection: PackageSortKey

    var body: some View {
        BrewweryTabs(
            options: PackageSortKey.allCases.map { ($0, $0.label) },
            selection: $selection
        )
    }
}

// MARK: - Shared confirmations

extension ConfirmationRequest {
    static func uninstall(_ reference: PackageReference) -> ConfirmationRequest {
        ConfirmationRequest(
            title: "Uninstall \(reference.name)?",
            message: "Brewwery will run",
            command: HomebrewCommand.uninstall(reference).displayCommand(),
            note: "This may remove the selected \(reference.kind == .cask ? "cask" : "package") from your Homebrew environment. Dependencies are not automatically removed unless Homebrew does it.",
            confirmLabel: "Uninstall"
        )
    }

    static func install(_ reference: PackageReference) -> ConfirmationRequest {
        ConfirmationRequest(
            title: "Install \(reference.name)?",
            message: "Brewwery will run",
            command: HomebrewCommand.install(reference).displayCommand(),
            confirmLabel: "Install"
        )
    }
}
