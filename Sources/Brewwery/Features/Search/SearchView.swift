import BrewweryCore
import SwiftUI

/// `pages/search.tsx` — debounced Homebrew search with install and uninstall.
struct SearchView: View {
    @Environment(AppEnvironment.self) private var brewwery

    @State private var search: SearchModel?
    @State private var info: PackageInfoModel?
    @State private var confirmation: ConfirmationRequest?
    @State private var pending: (action: OperationKind, reference: PackageReference)?

    private var visibleError: BrewweryError? {
        search?.error ?? info?.error
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.sectionSpacing) {
            PageHeader(
                title: "Search",
                subtitle: "Discover Homebrew formulae and casks, inspect details, then install safely."
            )

            content
        }
        .onAppear {
            if search == nil { search = SearchModel(client: brewwery.client) }
            if info == nil { info = PackageInfoModel(client: brewwery.client) }
            search?.search(brewwery.state.searchQuery)
        }
        .onChange(of: brewwery.state.searchQuery) { _, query in
            search?.search(query)
        }
        .overlay { drawer }
        .confirmation($confirmation, isWorking: brewwery.operations.isRunning) { _ in
            Task { await confirm() }
        }
    }

    @ViewBuilder
    private var content: some View {
        if let search {
            if search.isSearching {
                StatePanel(title: "Searching Homebrew...", kind: .loading)
            } else if search.hasInvalidQuery {
                StatePanel(title: "Use Latin characters to search Homebrew packages") {
                    Text("Homebrew package search supports letters, numbers, @, -, _, ., and +.")
                }
            } else if let error = visibleError {
                if error.code == .homebrewNotFound {
                    HomebrewNotFoundPanel()
                } else {
                    StatePanel(title: "Failed to search packages", kind: .error) {
                        ErrorDescriptionView(error: error)
                    }
                }
            } else if search.activeQuery.isEmpty {
                StatePanel(title: "Search Homebrew packages") {
                    Text("Type a package or app name to search formulae and casks.")
                }
            } else if search.results.isEmpty {
                StatePanel(title: "No packages found")
            }

            OperationProgressPanel()

            if !search.isSearching, !search.hasInvalidQuery, visibleError == nil, !search.results.isEmpty {
                table(for: search.results)
            }
        }
    }

    private func table(for results: [PackageSearchResult]) -> some View {
        BrewweryTable(
            accessibilityLabel: "Search results",
            items: results,
            columns: [
                TableColumnSpec("Package", width: .flexible(minimum: 200, weight: 2)) { result in
                    HStack(spacing: Metrics.tightSpacing) {
                        Text(result.name)
                            .font(BrewweryFont.controlLabel)
                            .foregroundStyle(BrewweryColor.foreground)
                        if brewwery.favorites.isFavorite(name: result.name, kind: result.kind) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(BrewweryColor.accent)
                        }
                    }
                    .lineLimit(1)
                },
                TableColumnSpec("Kind", width: .fixed(128)) { result in
                    BrewweryBadge.kind(result.kind)
                },
                TableColumnSpec("Status", width: .fixed(128)) { result in
                    if brewwery.library.isLoading {
                        BrewweryBadge(text: "Checking...")
                    } else {
                        BrewweryBadge.installed(
                            brewwery.library.isInstalled(name: result.name, kind: result.kind)
                        )
                    }
                },
                TableColumnSpec("Actions", width: .fixed(136), alignment: .trailing) { result in
                    Button {
                        open(result)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "info.circle").font(.system(size: 12))
                            Text("Details")
                        }
                    }
                    .brewweryButton(.ghost, height: Metrics.compactControlHeight)
                    .disabled(info?.isLoading == true)
                }
            ],
            rowHeight: 56,
            maxHeight: 560,
            onActivate: open
        )
    }

    @ViewBuilder
    private var drawer: some View {
        if let info, let detail = info.hydrated(with: brewwery.library) {
            PackageDetailDrawer(
                detail: .info(detail),
                isWorking: brewwery.operations.isRunning || info.isLoading,
                dependents: info.dependents,
                isLoadingDependents: info.isLoadingDependents,
                onClose: { info.clear() },
                onInstall: { request(.install, $0) },
                onUninstall: { request(.uninstall, $0) }
            )
        }
    }

    private func open(_ result: PackageSearchResult) {
        Task {
            let reference = PackageReference(name: result.name, kind: result.kind)
            await info?.load(reference)
            info?.loadDependents(for: info?.info?.installed == true ? reference : nil)
        }
    }

    private func request(_ action: OperationKind, _ reference: PackageReference) {
        pending = (action, reference)
        confirmation = action == .install ? .install(reference) : .uninstall(reference)
    }

    private func confirm() async {
        guard let pending else { return }
        switch pending.action {
        case .install: await brewwery.installPackage(pending.reference)
        case .uninstall: await brewwery.uninstallPackage(pending.reference)
        default: break
        }
        await info?.load(pending.reference)
        self.pending = nil
    }
}
