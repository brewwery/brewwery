import BrewweryCore
import SwiftUI

/// `pages/favorites.tsx` — locally saved packages, resolved against the installed caches.
struct FavoritesView: View {
    @Environment(AppEnvironment.self) private var brewwery

    @State private var info: PackageInfoModel?

    private struct Row: Identifiable, Hashable {
        let favorite: FavoritePackage
        let displayName: String
        let isInstalled: Bool
        var id: String { favorite.id }
    }

    private var rows: [Row] {
        brewwery.favorites.favorites
            .map { favorite in
                Row(
                    favorite: favorite,
                    displayName: brewwery.library.displayName(for: favorite.name, kind: favorite.kind),
                    isInstalled: brewwery.library.isInstalled(name: favorite.name, kind: favorite.kind)
                )
            }
            .sorted { $0.favorite.name.localizedStandardCompare($1.favorite.name) == .orderedAscending }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.sectionSpacing) {
            PageHeader(title: "Favorites", subtitle: "Saved Homebrew packages and casks.")

            if let error = info?.error {
                StatePanel(title: "Failed to load package details", kind: .error) {
                    ErrorDescriptionView(error: error)
                }
            }

            if rows.isEmpty {
                StatePanel(title: "No favorites yet") {
                    Text("Add packages from Search, Discover, Packages, or Casks.")
                }
            } else {
                table
            }
        }
        .onAppear { if info == nil { info = PackageInfoModel(client: brewwery.client) } }
        .task { if brewwery.library.formulae.isEmpty { await brewwery.library.loadAll() } }
        .overlay { drawer }
    }

    private var table: some View {
        BrewweryTable(
            accessibilityLabel: "Favorite packages",
            items: rows,
            columns: [
                TableColumnSpec("Package", width: .flexible(minimum: 200, weight: 2)) { row in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: Metrics.tightSpacing) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(BrewweryColor.accent)
                            Text(row.displayName)
                                .font(BrewweryFont.controlLabel)
                                .foregroundStyle(BrewweryColor.foreground)
                        }
                        Text(row.favorite.name)
                            .font(BrewweryFont.caption)
                            .foregroundStyle(BrewweryColor.mutedForeground)
                    }
                    .lineLimit(1)
                },
                TableColumnSpec("Kind", width: .fixed(112)) { row in
                    BrewweryBadge.kind(row.favorite.kind)
                },
                TableColumnSpec("Status", width: .fixed(144)) { row in
                    Text(brewwery.library.isLoading ? "Checking..." : (row.isInstalled ? "Installed" : "Available"))
                        .font(BrewweryFont.body)
                        .foregroundStyle(BrewweryColor.mutedForeground)
                },
                TableColumnSpec("Actions", width: .fixed(184), alignment: .trailing) { row in
                    HStack(spacing: Metrics.tightSpacing) {
                        Button {
                            open(row)
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "info.circle").font(.system(size: 12))
                                Text("Details")
                            }
                        }
                        .brewweryButton(.ghost, height: Metrics.compactControlHeight)
                        .disabled(info?.isLoading == true)

                        IconButton(
                            "Remove \(row.favorite.name) from favorites",
                            systemImage: "trash",
                            height: Metrics.compactControlHeight
                        ) {
                            brewwery.favorites.remove(name: row.favorite.name, kind: row.favorite.kind)
                        }
                    }
                }
            ],
            rowHeight: 64,
            maxHeight: 560,
            onActivate: open
        )
    }

    @ViewBuilder
    private var drawer: some View {
        if let info, let detail = info.info {
            PackageDetailDrawer(
                detail: .info(detail),
                isWorking: info.isLoading,
                dependents: info.dependents,
                isLoadingDependents: info.isLoadingDependents,
                onClose: { info.clear() }
            )
        }
    }

    private func open(_ row: Row) {
        Task {
            let reference = PackageReference(name: row.favorite.name, kind: row.favorite.kind)
            await info?.load(reference)
            info?.loadDependents(for: info?.info?.installed == true ? reference : nil)
        }
    }
}
