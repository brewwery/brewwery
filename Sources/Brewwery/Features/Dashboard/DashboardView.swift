import BrewweryCore
import SwiftUI

/// `pages/dashboard.tsx` — a read-only overview. Nothing here mutates Homebrew; "Refresh
/// data" reloads what Brewwery already knows and never runs `brew update`.
struct DashboardView: View {
    @Environment(AppEnvironment.self) private var brewwery
    @State private var lastRefreshed: Date?
    @State private var isRefreshing = false

    private var system: SystemModel { brewwery.system }
    private var library: PackageLibrary { brewwery.library }
    private var updates: UpdatesModel { brewwery.updates }
    private var services: ServicesModel { brewwery.services }

    private var isLoadingSomething: Bool {
        system.isLoading || library.isLoading || updates.isLoading || services.isLoading
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.sectionSpacing) {
            header

            if system.isHomebrewMissing {
                HomebrewNotFoundPanel()
            }

            statusStrip
            statistics
            panels
            homebrewDetails
        }
        .task {
            await withTaskGroup { group in
                group.addTask { await library.loadAll() }
                group.addTask { await updates.refresh() }
                group.addTask { await services.refresh() }
            }
        }
    }

    private var header: some View {
        PageHeader(title: "Dashboard", subtitle: subtitle) {
            ActionButton(
                title: "Refresh data",
                systemImage: "arrow.clockwise",
                isBusy: isRefreshing
            ) {
                Task { await refreshAll() }
            }
            .disabled(isLoadingSomething)
            .help("Reloads current Homebrew data without running brew update")
        }
    }

    private var subtitle: String {
        let suffix = isLoadingSomething
            ? "Refreshing..."
            : lastRefreshed.map { "Last refreshed \($0.formatted(date: .omitted, time: .standard))" } ?? "Live data ready"
        return "A quick read on this Mac's Homebrew installation.  \(suffix)"
    }

    private var statusStrip: some View {
        BrewweryCard {
            HStack(spacing: Metrics.rowSpacing) {
                Circle()
                    .fill(statusTone)
                    .frame(width: 10, height: 10)
                Text(system.isLoading ? "Checking Homebrew..." : (system.detection?.found == true ? "Homebrew running" : "Homebrew not found"))
                    .foregroundStyle(BrewweryColor.foreground)
                Text(system.info?.version ?? "Version pending")
                Text(system.info?.prefix ?? "Prefix pending")
                Text(system.info?.architecture.rawValue ?? "arch pending")
                Spacer(minLength: Metrics.tightSpacing)
                BrewweryBadge(text: isLoadingSomething ? "Updating" : "Live data")
            }
            .font(BrewweryFont.body)
            .foregroundStyle(BrewweryColor.mutedForeground)
            .lineLimit(1)
        }
    }

    private var statusTone: Color {
        if system.error != nil { return BrewweryColor.danger }
        if system.detection?.found == true { return BrewweryColor.success }
        if system.isLoading { return BrewweryColor.accent }
        return BrewweryColor.mutedForeground
    }

    private var statistics: some View {
        HStack(spacing: Metrics.cardSpacing) {
            StatCard(label: "Formulae", value: library.formulae.count, isLoading: library.isLoadingFormulae, systemImage: "shippingbox")
            StatCard(label: "Casks", value: library.casks.count, isLoading: library.isLoadingCasks, systemImage: "archivebox")
            StatCard(label: "Updates", value: updates.updates.count, isLoading: updates.isLoading, systemImage: "arrow.down.circle")
            StatCard(label: "Services", value: services.services.count, isLoading: services.isLoading, systemImage: "waveform.path.ecg")
        }
    }

    private var panels: some View {
        HStack(alignment: .top, spacing: Metrics.cardSpacing) {
            servicesPanel
            updatesPanel
        }
    }

    private var servicesPanel: some View {
        BrewweryHeaderCard {
            PanelHeader(
                title: "Services",
                subtitle: services.isLoading
                    ? "Loading services..."
                    : "\(services.count(of: .started)) running, \(services.count(of: .stopped)) stopped"
            ) { brewwery.state.select(.services) }
        } content: {
            VStack(alignment: .leading, spacing: Metrics.rowSpacing) {
                HStack(spacing: Metrics.tightSpacing) {
                    ServicePill(label: "Started", value: services.count(of: .started), tone: .success)
                    ServicePill(label: "Stopped", value: services.count(of: .stopped), tone: .neutral)
                    ServicePill(label: "Errors", value: services.count(of: .error), tone: .danger)
                }

                // With Homebrew missing the panel at the top already says why; repeating it in
                // every card only adds red.
                if let error = services.error, !system.isHomebrewMissing {
                    InlineErrorView(message: error.message.isEmpty ? "Failed to load services" : error.message)
                } else if !services.isLoading, services.services.isEmpty {
                    EmptyLine(text: "No Homebrew services found")
                } else if services.isLoading, services.services.isEmpty {
                    SkeletonRows(count: 4)
                }

                ForEach(services.runningFirst.prefix(5)) { service in
                    ServiceSummaryRow(service: service)
                }
            }
        }
    }

    private var updatesPanel: some View {
        BrewweryHeaderCard {
            PanelHeader(
                title: "Updates",
                subtitle: updates.isLoading ? "Checking outdated packages..." : "\(updates.updates.count) available updates"
            ) { brewwery.state.select(.updates) }
        } content: {
            VStack(alignment: .leading, spacing: Metrics.rowSpacing) {
                MiniBars(
                    items: [
                        (label: "Formulae", value: updates.formulaeCount, color: BrewweryColor.warning),
                        (label: "Casks", value: updates.casksCount, color: BrewweryColor.caskAccent)
                    ]
                )

                if updates.error != nil, !system.isHomebrewMissing {
                    InlineErrorView(message: "Failed to load updates")
                } else if !updates.isLoading, updates.updates.isEmpty {
                    EmptyLine(text: "Everything is up to date")
                } else if updates.isLoading, updates.updates.isEmpty {
                    SkeletonRows(count: 4)
                }

                ForEach(updates.updates.prefix(6)) { update in
                    UpdateSummaryRow(update: update)
                }
            }
        }
    }

    private var homebrewDetails: some View {
        BrewweryHeaderCard {
            Text("Homebrew")
                .font(BrewweryFont.panelTitle)
                .foregroundStyle(BrewweryColor.foreground)
        } content: {
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: Metrics.cardSpacing), count: 3),
                spacing: Metrics.cardSpacing
            ) {
                InfoBox(label: "Status", value: system.isLoading ? "Checking..." : (system.detection?.found == true ? "Detected" : "Not detected"))
                InfoBox(label: "Version", value: system.info?.version ?? "Unknown")
                InfoBox(label: "Prefix", value: system.info?.prefix ?? "Unknown")
                InfoBox(label: "Executable", value: system.info?.path ?? "Unknown")
                InfoBox(label: "Architecture", value: system.info?.architecture.rawValue ?? "unknown")
                InfoBox(label: "Formulae / Casks", value: "\(library.formulae.count) / \(library.casks.count)")
            }
        }
    }

    private func refreshAll() async {
        isRefreshing = true
        defer { isRefreshing = false }

        await withTaskGroup { group in
            group.addTask { await system.load() }
            group.addTask { await library.loadAll() }
            group.addTask { await updates.refresh() }
            group.addTask { await services.refresh() }
        }
        lastRefreshed = Date()
    }
}

// MARK: - Pieces

private struct StatCard: View {
    let label: String
    let value: Int
    let isLoading: Bool
    let systemImage: String

    var body: some View {
        BrewweryCard {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(label)
                        .font(BrewweryFont.body)
                        .foregroundStyle(BrewweryColor.mutedForeground)
                    Text(isLoading ? "..." : String(value))
                        .font(BrewweryFont.statValue)
                        .foregroundStyle(BrewweryColor.foreground)
                }
                Spacer()
                Image(systemName: systemImage)
                    .font(.system(size: 18))
                    .foregroundStyle(BrewweryColor.accent)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(isLoading ? "loading" : String(value))")
    }
}

private struct PanelHeader: View {
    let title: String
    let subtitle: String
    let viewAll: () -> Void

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(BrewweryFont.panelTitle)
                    .foregroundStyle(BrewweryColor.foreground)
                Text(subtitle)
                    .font(BrewweryFont.caption)
                    .foregroundStyle(BrewweryColor.mutedForeground)
            }
            Spacer()
            Button("View all", action: viewAll)
                .brewweryButton(.ghost, height: Metrics.compactControlHeight)
        }
    }
}

private struct ServicePill: View {
    let label: String
    let value: Int
    let tone: BrewweryBadge.Tone

    var body: some View {
        HStack(spacing: Metrics.tightSpacing) {
            Text(label).foregroundStyle(tone.foreground)
            Text(String(value))
                .font(BrewweryFont.captionEmphasis)
                .foregroundStyle(BrewweryColor.foreground)
        }
        .font(BrewweryFont.caption)
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(tone.background, in: Capsule())
        .overlay(Capsule().strokeBorder(tone.border, lineWidth: 1))
    }
}

private struct ServiceSummaryRow: View {
    let service: BrewService

    var body: some View {
        HStack(spacing: Metrics.rowSpacing) {
            Image(systemName: "server.rack")
                .font(.system(size: 13))
                .foregroundStyle(BrewweryColor.mutedForeground)
            VStack(alignment: .leading, spacing: 2) {
                Text(service.name)
                    .font(BrewweryFont.controlLabel)
                    .foregroundStyle(BrewweryColor.foreground)
                Text(service.file ?? service.user ?? "Homebrew service")
                    .font(BrewweryFont.caption)
                    .foregroundStyle(BrewweryColor.mutedForeground)
            }
            .lineLimit(1)
            .truncationMode(.middle)
            Spacer(minLength: Metrics.tightSpacing)
            ServiceStatusBadge(status: service.status)
        }
        .padding(.horizontal, Metrics.rowSpacing)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(BrewweryColor.background.opacity(0.45))
        .clipShape(RoundedRectangle(cornerRadius: Metrics.controlRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Metrics.controlRadius, style: .continuous)
                .strokeBorder(BrewweryColor.border, lineWidth: 1)
        )
    }
}

private struct UpdateSummaryRow: View {
    let update: OutdatedPackage

    var body: some View {
        HStack(spacing: Metrics.rowSpacing) {
            Image(systemName: "arrow.down.circle")
                .font(.system(size: 13))
                .foregroundStyle(BrewweryColor.mutedForeground)
            VStack(alignment: .leading, spacing: 2) {
                Text(update.name)
                    .font(BrewweryFont.controlLabel)
                    .foregroundStyle(BrewweryColor.foreground)
                Text("\(update.currentVersion ?? update.installedVersions.first ?? "unknown") -> \(update.latestVersion ?? "unknown")")
                    .font(BrewweryFont.caption)
                    .foregroundStyle(BrewweryColor.mutedForeground)
            }
            .lineLimit(1)
            Spacer(minLength: Metrics.tightSpacing)
            BrewweryBadge.kind(update.kind)
        }
        .padding(Metrics.rowSpacing)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(BrewweryColor.background.opacity(0.45))
        .clipShape(RoundedRectangle(cornerRadius: Metrics.controlRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Metrics.controlRadius, style: .continuous)
                .strokeBorder(BrewweryColor.border, lineWidth: 1)
        )
    }
}

private struct MiniBars: View {
    let items: [(label: String, value: Int, color: Color)]

    var body: some View {
        let maximum = max(items.map(\.value).max() ?? 1, 1)

        VStack(spacing: Metrics.tightSpacing) {
            ForEach(items, id: \.label) { item in
                HStack(spacing: Metrics.rowSpacing) {
                    Text(item.label)
                        .font(BrewweryFont.caption)
                        .foregroundStyle(BrewweryColor.mutedForeground)
                        .frame(width: 90, alignment: .leading)

                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Capsule().fill(BrewweryColor.muted)
                            Capsule()
                                .fill(item.color)
                                .frame(
                                    width: geometry.size.width
                                        * max(Double(item.value) / Double(maximum), item.value > 0 ? 0.08 : 0)
                                )
                        }
                    }
                    .frame(height: 8)

                    Text(String(item.value))
                        .font(BrewweryFont.caption)
                        .foregroundStyle(BrewweryColor.foreground)
                        .frame(width: 40, alignment: .trailing)
                }
            }
        }
    }
}

private struct SkeletonRows: View {
    let count: Int
    @State private var isPulsing = false

    var body: some View {
        VStack(spacing: Metrics.rowSpacing) {
            ForEach(0..<count, id: \.self) { _ in
                RoundedRectangle(cornerRadius: Metrics.controlRadius, style: .continuous)
                    .fill(BrewweryColor.card)
                    .frame(height: 66)
                    .overlay(
                        RoundedRectangle(cornerRadius: Metrics.controlRadius, style: .continuous)
                            .strokeBorder(BrewweryColor.border, lineWidth: 1)
                    )
                    .opacity(isPulsing ? 0.5 : 1)
            }
        }
        .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: isPulsing)
        .onAppear { isPulsing = true }
        .accessibilityHidden(true)
    }
}

private struct EmptyLine: View {
    let text: String

    var body: some View {
        Text(text)
            .font(BrewweryFont.body)
            .foregroundStyle(BrewweryColor.mutedForeground)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Metrics.rowSpacing)
            .background(BrewweryColor.background.opacity(0.45))
            .clipShape(RoundedRectangle(cornerRadius: Metrics.controlRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Metrics.controlRadius, style: .continuous)
                    .strokeBorder(BrewweryColor.border, lineWidth: 1)
            )
    }
}

/// Shared by the Dashboard and the Services page.
struct ServiceStatusBadge: View {
    let status: ServiceStatus

    var body: some View {
        BrewweryBadge(text: status.rawValue, tone: tone)
    }

    private var tone: BrewweryBadge.Tone {
        switch status {
        case .started: .success
        case .error: .danger
        case .stopped, .unknown: .neutral
        }
    }
}
