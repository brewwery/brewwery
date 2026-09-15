import BrewweryCore
import SwiftUI

/// `pages/discover.tsx` — curated, locally bundled collections. No network request of its
/// own; the cards only name packages the user can inspect or install.
struct DiscoverView: View {
    @Environment(AppEnvironment.self) private var brewwery

    @State private var selectedCollectionID = DiscoverCatalog.collections.first?.id ?? ""
    @State private var info: PackageInfoModel?
    @State private var confirmation: ConfirmationRequest?
    @State private var pending: PackageReference?

    private var collection: DiscoverCollection {
        DiscoverCatalog.collections.first { $0.id == selectedCollectionID } ?? DiscoverCatalog.collections[0]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.sectionSpacing) {
            PageHeader(
                title: "Discover",
                subtitle: "Curated collections of useful Homebrew packages and casks."
            )

            collectionPicker

            if let error = info?.error {
                StatePanel(title: "Failed to load package details", kind: .error) {
                    ErrorDescriptionView(error: error)
                }
            }

            collectionCard
            OperationProgressPanel()
        }
        .onAppear { if info == nil { info = PackageInfoModel(client: brewwery.client) } }
        .task { if brewwery.library.formulae.isEmpty { await brewwery.library.loadAll() } }
        .overlay { drawer }
        .confirmation($confirmation, isWorking: brewwery.operations.isRunning) { _ in
            Task {
                guard let pending else { return }
                await brewwery.installPackage(pending)
                await info?.load(pending)
                self.pending = nil
            }
        }
    }

    private var collectionPicker: some View {
        FlowLayout(spacing: Metrics.tightSpacing) {
            ForEach(DiscoverCatalog.collections) { item in
                Button(item.title) { selectedCollectionID = item.id }
                    .brewweryButton(
                        item.id == collection.id ? .primary : .secondary,
                        height: Metrics.compactControlHeight
                    )
                    .accessibilityAddTraits(item.id == collection.id ? [.isSelected] : [])
            }
        }
    }

    private var collectionCard: some View {
        BrewweryHeaderCard {
            HStack(alignment: .top, spacing: Metrics.cardSpacing) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(collection.title)
                        .font(BrewweryFont.cardTitle)
                        .foregroundStyle(BrewweryColor.foreground)
                    Text(collection.description)
                        .font(BrewweryFont.body)
                        .foregroundStyle(BrewweryColor.mutedForeground)
                }
                Spacer(minLength: Metrics.tightSpacing)
                HStack(spacing: Metrics.tightSpacing) {
                    BrewweryBadge(text: "\(collection.items.count) packages")
                    BrewweryBadge(text: "\(installedCount) installed", tone: .success)
                    BrewweryBadge(text: "\(favoriteCount) favorites", tone: .accent)
                    BrewweryBadge(text: "\(collection.items.count - installedCount) available")
                }
            }
        } content: {
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: Metrics.rowSpacing), count: 3),
                spacing: Metrics.rowSpacing
            ) {
                ForEach(collection.items) { item in
                    DiscoverCard(
                        item: item,
                        isInstalled: brewwery.library.isInstalled(name: item.name, kind: item.kind),
                        isFavorite: brewwery.favorites.isFavorite(name: item.name, kind: item.kind),
                        onDetails: { Task { await info?.load(item.reference) } },
                        onInstall: {
                            pending = item.reference
                            confirmation = .install(item.reference)
                        },
                        onToggleFavorite: { brewwery.favorites.toggle(name: item.name, kind: item.kind) }
                    )
                }
            }
        }
    }

    @ViewBuilder
    private var drawer: some View {
        if let info, let detail = info.info {
            PackageDetailDrawer(
                detail: .info(detail),
                isWorking: brewwery.operations.isRunning || info.isLoading,
                dependents: info.dependents,
                isLoadingDependents: info.isLoadingDependents,
                onClose: { info.clear() },
                onInstall: { reference in
                    pending = reference
                    confirmation = .install(reference)
                }
            )
        }
    }

    private var installedCount: Int {
        collection.items.count { brewwery.library.isInstalled(name: $0.name, kind: $0.kind) }
    }

    private var favoriteCount: Int {
        collection.items.count { brewwery.favorites.isFavorite(name: $0.name, kind: $0.kind) }
    }
}

private struct DiscoverCard: View {
    let item: DiscoverItem
    let isInstalled: Bool
    let isFavorite: Bool
    let onDetails: () -> Void
    let onInstall: () -> Void
    let onToggleFavorite: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.tightSpacing) {
            HStack(alignment: .top, spacing: Metrics.rowSpacing) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: Metrics.tightSpacing) {
                        Text(item.name)
                            .font(BrewweryFont.controlLabel)
                            .foregroundStyle(BrewweryColor.foreground)
                        if isFavorite {
                            Image(systemName: "star.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(BrewweryColor.accent)
                        }
                    }
                    Text(item.description ?? "Curated Homebrew package.")
                        .font(BrewweryFont.caption)
                        .foregroundStyle(BrewweryColor.mutedForeground)
                        .lineSpacing(3)
                        .frame(minHeight: 40, alignment: .top)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                BrewweryBadge.kind(item.kind)
            }

            BrewweryBadge.installed(isInstalled)

            HStack(spacing: Metrics.tightSpacing) {
                ActionButton(title: "Details", systemImage: "info.circle", height: Metrics.compactControlHeight, action: onDetails)
                    .frame(maxWidth: .infinity)

                if !isInstalled {
                    ActionButton(
                        title: "Install",
                        systemImage: "arrow.down.circle",
                        variant: .primary,
                        height: Metrics.compactControlHeight,
                        action: onInstall
                    )
                    .frame(maxWidth: .infinity)
                }

                IconButton(
                    isFavorite ? "Remove \(item.name) from favorites" : "Add \(item.name) to favorites",
                    systemImage: isFavorite ? "star.fill" : "star",
                    variant: isFavorite ? .secondary : .ghost,
                    height: Metrics.compactControlHeight,
                    tint: isFavorite ? BrewweryColor.accent : BrewweryColor.mutedForeground,
                    action: onToggleFavorite
                )
            }
            .padding(.top, 4)
        }
        .padding(Metrics.rowSpacing)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(BrewweryColor.pre)
        .clipShape(RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous)
                .strokeBorder(BrewweryColor.border, lineWidth: 1)
        )
    }
}
