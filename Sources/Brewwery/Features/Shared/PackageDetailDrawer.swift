import BrewweryCore
import SwiftUI

/// The three shapes the drawer can be opened with, matching the legacy `PackageDetail`
/// union: an installed formula row, an installed cask row, or a full `brew info` payload.
enum PackageDetail: Identifiable, Hashable {
    case formula(Formula)
    case cask(Cask)
    case info(PackageInfo)

    var id: String {
        switch self {
        case .formula(let formula): "formula:\(formula.name)"
        case .cask(let cask): "cask:\(cask.token)"
        case .info(let info): info.id
        }
    }

    var reference: PackageReference {
        switch self {
        case .formula(let formula): PackageReference(name: formula.name, kind: .formula)
        case .cask(let cask): PackageReference(name: cask.token, kind: .cask)
        case .info(let info): PackageReference(name: info.token ?? info.name, kind: info.kind)
        }
    }
}

/// `components/packages/package-detail-drawer.tsx` — a 420 pt panel over a scrim, closed
/// with Escape or by clicking outside.
///
/// The information hierarchy is unchanged from 0.9.7: badges, versions, description,
/// homepage, dependencies, installed dependents, caveats, actions, raw JSON.
struct PackageDetailDrawer: View {
    @Environment(AppEnvironment.self) private var brewwery

    let detail: PackageDetail
    var isWorking = false
    var dependents: [String] = []
    var isLoadingDependents = false
    var onClose: () -> Void
    var onInstall: ((PackageReference) -> Void)?
    var onUninstall: ((PackageReference) -> Void)?
    var onUpgrade: ((PackageReference) -> Void)?

    private var model: DetailModel { DetailModel(detail: detail) }

    var body: some View {
        ZStack(alignment: .trailing) {
            BrewweryColor.overlay
                .ignoresSafeArea()
                .onTapGesture(perform: onClose)

            VStack(alignment: .leading, spacing: 0) {
                header
                Divider().overlay(BrewweryColor.border)
                ScrollView {
                    VStack(alignment: .leading, spacing: Metrics.sectionSpacing) {
                        badges
                        InfoRow(label: "Installed version", value: model.installedVersion ?? "Not installed")
                        InfoRow(label: "Latest version", value: model.latestVersion ?? "Unknown")
                        InfoRow(label: "Description", value: model.description ?? "No description available.")
                        homepage
                        dependencies
                        dependentsSection
                        caveats
                        Divider().overlay(BrewweryColor.border)
                        actions
                        rawJSON
                    }
                    .padding(Metrics.sectionSpacing)
                }
            }
            .frame(width: Metrics.drawerWidth)
            .frame(maxHeight: .infinity)
            .background(BrewweryColor.appPanel)
            .overlay(alignment: .leading) { Divider().overlay(BrewweryColor.border) }
            .shadow(color: BrewweryColor.panelShadow, radius: 25, x: 0, y: 16)
            .transition(.move(edge: .trailing))
        }
        .onExitCommand(perform: onClose)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Details for \(model.title)")
    }

    private var header: some View {
        HStack(spacing: Metrics.rowSpacing) {
            VStack(alignment: .leading, spacing: 2) {
                Text(model.title)
                    .font(BrewweryFont.panelTitle)
                    .foregroundStyle(BrewweryColor.foreground)
                Text(model.subtitle)
                    .font(BrewweryFont.caption)
                    .foregroundStyle(BrewweryColor.mutedForeground)
            }
            .lineLimit(1)

            Spacer(minLength: 0)

            Button("Close", action: onClose)
                .brewweryButton(.ghost, height: Metrics.compactControlHeight)
                .accessibilityLabel("Close details for \(model.title)")
        }
        .padding(.horizontal, Metrics.sectionSpacing)
        .frame(height: 56)
    }

    private var badges: some View {
        HStack(spacing: Metrics.tightSpacing) {
            BrewweryBadge.kind(model.reference.kind)
            if isFavorite {
                BrewweryBadge(text: "Favorite", tone: .accent, systemImage: "star.fill")
            }
            BrewweryBadge.installed(model.installed)
            if let onRequest = model.installedOnRequest {
                BrewweryBadge(text: onRequest ? "On request" : "Dependency")
            }
        }
    }

    @ViewBuilder
    private var homepage: some View {
        if let homepage = model.homepage {
            VStack(alignment: .leading, spacing: 4) {
                Text("Homepage")
                    .font(BrewweryFont.caption)
                    .foregroundStyle(BrewweryColor.mutedForeground)
                Button {
                    ExternalLink.openHomepage(homepage)
                } label: {
                    HStack(spacing: Metrics.tightSpacing) {
                        Image(systemName: "arrow.up.forward.square")
                            .font(.system(size: 11))
                        Text(homepage)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    .font(BrewweryFont.body)
                    .foregroundStyle(BrewweryColor.accent)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var dependencies: some View {
        VStack(alignment: .leading, spacing: Metrics.tightSpacing) {
            Text("Dependencies")
                .font(BrewweryFont.caption)
                .foregroundStyle(BrewweryColor.mutedForeground)

            if let dependencies = model.dependencies, !dependencies.isEmpty {
                FlowLayout(spacing: Metrics.tightSpacing) {
                    ForEach(dependencies, id: \.self) { BrewweryBadge(text: $0) }
                }
            } else {
                PlaceholderBox(text: "No dependencies listed.")
            }
        }
    }

    @ViewBuilder
    private var dependentsSection: some View {
        if model.reference.kind == .formula, model.installed {
            VStack(alignment: .leading, spacing: Metrics.tightSpacing) {
                Text("Installed dependents")
                    .font(BrewweryFont.caption)
                    .foregroundStyle(BrewweryColor.mutedForeground)

                if isLoadingDependents {
                    PlaceholderBox(text: "Checking dependents...")
                } else if dependents.isEmpty {
                    PlaceholderBox(text: "No installed packages depend on this formula.")
                } else {
                    FlowLayout(spacing: Metrics.tightSpacing) {
                        ForEach(dependents, id: \.self) { BrewweryBadge(text: $0) }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var caveats: some View {
        if let caveats = model.caveats {
            InfoRow(label: "Caveats", value: caveats)
        }
    }

    private var actions: some View {
        VStack(spacing: Metrics.tightSpacing) {
            DrawerAction(
                title: isFavorite ? "Remove from Favorites" : "Add to Favorites",
                systemImage: isFavorite ? "star.fill" : "star",
                tint: isFavorite ? BrewweryColor.accent : nil
            ) {
                brewwery.favorites.toggle(name: model.reference.name, kind: model.reference.kind)
            }

            if model.installed {
                DrawerAction(title: "Uninstall", systemImage: "trash", isEnabled: onUninstall != nil && !isWorking) {
                    onUninstall?(model.reference)
                }
            } else {
                DrawerAction(title: "Install", systemImage: "arrow.down.circle", isEnabled: onInstall != nil && !isWorking) {
                    onInstall?(model.reference)
                }
            }

            DrawerAction(
                title: "Upgrade",
                systemImage: "arrow.up.circle",
                isEnabled: onUpgrade != nil && !isWorking,
                help: onUpgrade == nil ? "Use Updates page" : nil
            ) {
                onUpgrade?(model.reference)
            }

            DrawerAction(title: "Copy package name", systemImage: "doc.on.doc") {
                Clipboard.copy(model.reference.name)
            }
            DrawerAction(title: "Copy install command", systemImage: "doc.on.doc") {
                Clipboard.copy(HomebrewCommand.install(model.reference).displayCommand())
            }
            DrawerAction(title: "Copy uninstall command", systemImage: "doc.on.doc", isEnabled: model.installed) {
                Clipboard.copy(HomebrewCommand.uninstall(model.reference).displayCommand())
            }
            DrawerAction(title: "Copy upgrade command", systemImage: "doc.on.doc", isEnabled: model.installed) {
                Clipboard.copy(HomebrewCommand.upgrade(model.reference).displayCommand())
            }
            DrawerAction(
                title: "Open homepage",
                systemImage: "arrow.up.forward.square",
                isEnabled: model.homepage != nil
            ) {
                if let homepage = model.homepage { ExternalLink.openHomepage(homepage) }
            }
        }
    }

    @ViewBuilder
    private var rawJSON: some View {
        if let rawJSON = model.rawJSON {
            OutputDisclosure(label: "Show raw JSON", content: rawJSON, maxHeight: 256)
        }
    }

    private var isFavorite: Bool {
        brewwery.favorites.isFavorite(name: model.reference.name, kind: model.reference.kind)
    }
}

// MARK: - Normalisation

/// `normalizeDetail()` — flattens the three input shapes into one presentation model.
private struct DetailModel {
    let title: String
    let subtitle: String
    let reference: PackageReference
    let installed: Bool
    let installedVersion: String?
    let latestVersion: String?
    let description: String?
    let homepage: String?
    let dependencies: [String]?
    let caveats: String?
    let rawJSON: String?
    let installedOnRequest: Bool?

    init(detail: PackageDetail) {
        switch detail {
        case .info(let info):
            title = info.displayName?.first ?? info.name
            subtitle = info.fullName ?? info.token ?? info.name
            reference = PackageReference(name: info.token ?? info.name, kind: info.kind)
            installed = info.installed
            installedVersion = info.installedVersion
            latestVersion = info.latestVersion
            description = info.description
            homepage = info.homepage
            dependencies = info.dependencies
            caveats = info.caveats
            rawJSON = info.rawJSON
            installedOnRequest = nil

        case .formula(let formula):
            title = formula.name
            subtitle = formula.fullName ?? formula.name
            reference = PackageReference(name: formula.name, kind: .formula)
            // Rows in Packages only ever show installed formulae.
            installed = true
            installedVersion = formula.installedVersion
            latestVersion = nil
            description = formula.description
            homepage = formula.homepage
            dependencies = formula.dependencies
            caveats = nil
            rawJSON = nil
            installedOnRequest = formula.installedOnRequest

        case .cask(let cask):
            title = cask.displayName
            subtitle = cask.token
            reference = PackageReference(name: cask.token, kind: .cask)
            installed = true
            installedVersion = cask.installedVersion
            latestVersion = nil
            description = cask.description
            homepage = cask.homepage
            dependencies = nil
            caveats = nil
            rawJSON = nil
            installedOnRequest = nil
        }
    }
}

// MARK: - Pieces

private struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(BrewweryFont.caption)
                .foregroundStyle(BrewweryColor.mutedForeground)
            Text(value)
                .font(BrewweryFont.body)
                .foregroundStyle(BrewweryColor.foreground)
                .lineSpacing(4)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(Metrics.rowSpacing)
                .background(BrewweryColor.pre)
                .clipShape(RoundedRectangle(cornerRadius: Metrics.controlRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: Metrics.controlRadius, style: .continuous)
                        .strokeBorder(BrewweryColor.border, lineWidth: 1)
                )
        }
    }
}

private struct PlaceholderBox: View {
    let text: String

    var body: some View {
        Text(text)
            .font(BrewweryFont.body)
            .foregroundStyle(BrewweryColor.mutedForeground)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Metrics.rowSpacing)
            .background(BrewweryColor.pre)
            .clipShape(RoundedRectangle(cornerRadius: Metrics.controlRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Metrics.controlRadius, style: .continuous)
                    .strokeBorder(BrewweryColor.border, lineWidth: 1)
            )
    }
}

private struct DrawerAction: View {
    let title: String
    let systemImage: String
    var tint: Color?
    var isEnabled = true
    var help: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Metrics.tightSpacing) {
                Image(systemName: systemImage)
                    .font(.system(size: 13))
                    .foregroundStyle(tint ?? BrewweryColor.foreground)
                Text(title)
                Spacer(minLength: 0)
            }
        }
        .brewweryButton(.secondary, fullWidth: true, alignment: .leading)
        .disabled(!isEnabled)
        .help(help ?? "")
    }
}

/// Wraps badge chips onto multiple lines, the native equivalent of `flex-wrap`.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var rowWidth: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if rowWidth > 0, rowWidth + spacing + size.width > width {
                totalHeight += rowHeight + spacing
                rowWidth = size.width
                rowHeight = size.height
            } else {
                rowWidth += rowWidth > 0 ? spacing + size.width : size.width
                rowHeight = max(rowHeight, size.height)
            }
        }

        return CGSize(width: width == .infinity ? rowWidth : width, height: totalHeight + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var origin = bounds.origin
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if origin.x > bounds.minX, origin.x + size.width > bounds.maxX {
                origin.x = bounds.minX
                origin.y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: origin, proposal: ProposedViewSize(size))
            origin.x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

enum Clipboard {
    static func copy(_ value: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
    }
}
