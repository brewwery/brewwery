import BrewweryCore
import SwiftUI

/// `pages/history.tsx` — the local operation log, searchable, filterable and exportable.
struct HistoryView: View {
    @Environment(AppEnvironment.self) private var brewwery

    private enum Filter: Hashable {
        case all
        case failed
        case cancelled
        case kind(HistoryOperationKind)

        var label: String {
            switch self {
            case .all: "All"
            case .failed: "Failed"
            case .cancelled: "Cancelled"
            case .kind(let kind):
                switch kind {
                case .install: "Installs"
                case .uninstall: "Uninstalls"
                case .upgrade: "Upgrades"
                case .brewUpdate: "Metadata"
                case .tap: "Taps"
                case .service: "Services"
                case .cleanup: "Cleanup"
                case .doctor: "Doctor"
                case .brewfileExport: "Brewfile"
                }
            }
        }
    }

    private static let filters: [Filter] = [
        .all, .failed, .cancelled,
        .kind(.install), .kind(.uninstall), .kind(.upgrade), .kind(.brewUpdate),
        .kind(.tap), .kind(.service), .kind(.cleanup), .kind(.doctor), .kind(.brewfileExport)
    ]

    @State private var filter: Filter = .all
    @State private var query = ""
    @State private var visibleLimit = 40

    private var entries: [HistoryEntry] { brewwery.history.entries }

    private var visibleEntries: [HistoryEntry] {
        let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        return entries.filter { entry in
            switch filter {
            case .failed where entry.status != .failed: return false
            case .cancelled where entry.status != .cancelled: return false
            case .kind(let kind) where entry.kind != kind: return false
            default: break
            }

            guard !normalized.isEmpty else { return true }
            return [
                entry.title, entry.command, entry.target, entry.details,
                entry.stdout, entry.stderr, entry.error?.code.rawValue,
                entry.error?.message, entry.error?.raw
            ]
            .compactMap { $0?.lowercased() }
            .contains { $0.contains(normalized) }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.sectionSpacing) {
            PageHeader(
                title: "History",
                subtitle: "Local operation log with command summaries, output details, and timestamps.",
                filter: $query,
                filterPlaceholder: "Filter history..."
            ) {
                ActionButton(title: "Export JSON", systemImage: "square.and.arrow.down", action: export)
                    .disabled(entries.isEmpty)
                ActionButton(title: "Clear", systemImage: "trash") { brewwery.history.clear() }
                    .disabled(entries.isEmpty)
            }

            summary
            filterBar
            content
        }
    }

    private var summary: some View {
        HStack(spacing: Metrics.cardSpacing) {
            SummaryCard(label: "Operations", value: entries.count)
            SummaryCard(label: "Succeeded", value: entries.count { $0.status == .success })
            SummaryCard(label: "Failed", value: entries.count { $0.status == .failed })
            SummaryCard(label: "Cancelled", value: entries.count { $0.status == .cancelled })
        }
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            BrewweryTabs(
                options: Self.filters.map { ($0, $0.label) },
                selection: $filter
            )
        }
    }

    @ViewBuilder
    private var content: some View {
        if entries.isEmpty {
            StatePanel(title: "No operations yet")
        } else if visibleEntries.isEmpty {
            StatePanel(title: "No operations match this filter")
        } else {
            VStack(spacing: Metrics.rowSpacing) {
                ForEach(visibleEntries.prefix(visibleLimit)) { entry in
                    HistoryCard(entry: entry)
                }

                if visibleEntries.count > visibleLimit {
                    Button("Show \(min(40, visibleEntries.count - visibleLimit)) more") {
                        visibleLimit += 40
                    }
                    .brewweryButton(.secondary, fullWidth: true)
                }
            }
        }
    }

    private func export() {
        guard let data = try? brewwery.history.exportData() else { return }

        let panel = NSSavePanel()
        panel.nameFieldStringValue = HistoryStore.exportFileName()
        panel.message = "Export the local Brewwery operation history."

        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try data.write(to: url, options: .atomic)
        } catch {
            Log.persistence.error("History export failed")
        }
    }
}

private struct HistoryCard: View {
    let entry: HistoryEntry

    private var output: String { entry.combinedOutput }

    var body: some View {
        BrewweryCard {
            VStack(alignment: .leading, spacing: Metrics.rowSpacing) {
                HStack(alignment: .top, spacing: Metrics.cardSpacing) {
                    VStack(alignment: .leading, spacing: Metrics.tightSpacing) {
                        HStack(spacing: Metrics.tightSpacing) {
                            Image(systemName: "clock.arrow.circlepath")
                                .font(.system(size: 13))
                                .foregroundStyle(BrewweryColor.accent)
                            Text(entry.title)
                                .font(BrewweryFont.panelTitle)
                                .foregroundStyle(BrewweryColor.foreground)
                                .lineLimit(1)
                        }

                        HStack(spacing: Metrics.tightSpacing) {
                            BrewweryBadge(text: entry.kind.displayName)
                            BrewweryBadge(text: entry.status.rawValue, tone: tone)
                            Text(entry.timestamp.formatted(date: .abbreviated, time: .standard))
                            if let target = entry.target {
                                Text("Target: \(target)").lineLimit(1)
                            }
                        }
                        .font(BrewweryFont.caption)
                        .foregroundStyle(BrewweryColor.mutedForeground)

                        if let command = entry.command {
                            Text(command)
                                .font(BrewweryFont.monoCaption)
                                .foregroundStyle(BrewweryColor.mutedForeground)
                                .textSelection(.enabled)
                        }

                        if let error = entry.error {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(error.message)
                                Text(error.code.rawValue).font(BrewweryFont.monoCaption)
                            }
                            .font(BrewweryFont.body)
                            .foregroundStyle(BrewweryColor.danger)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(Metrics.rowSpacing)
                            .background(BrewweryColor.dangerBackground)
                            .clipShape(RoundedRectangle(cornerRadius: Metrics.controlRadius, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: Metrics.controlRadius, style: .continuous)
                                    .strokeBorder(BrewweryColor.dangerBorder, lineWidth: 1)
                            )
                        }
                    }

                    Spacer(minLength: Metrics.tightSpacing)

                    ActionButton(title: "Copy", systemImage: "doc.on.clipboard", height: Metrics.compactControlHeight) {
                        Clipboard.copy(output)
                    }
                    .disabled(output.isEmpty)
                }

                if !output.isEmpty {
                    OutputDisclosure(label: "Show output details", content: preview, maxHeight: 288)
                }
            }
        }
    }

    /// `outputPreview()` — the stored text can be long; the disclosure shows the first 8 000
    /// characters and Copy still yields everything.
    private var preview: String {
        let maximum = 8_000
        guard output.count > maximum else { return output }
        return String(output.prefix(maximum)) + "\n\n[Preview trimmed. Use Copy to copy the stored details.]"
    }

    private var tone: BrewweryBadge.Tone {
        switch entry.status {
        case .success: .success
        case .failed: .danger
        case .cancelled: .warning
        }
    }
}
