import BrewweryCore
import SwiftUI

/// `pages/cleanup.tsx` — preview first, then an explicitly confirmed run.
struct CleanupView: View {
    @Environment(AppEnvironment.self) private var brewwery

    @State private var confirmation: ConfirmationRequest?

    private var model: CleanupModel { brewwery.cleanup }
    private var isRunning: Bool { brewwery.operations.isRunning }

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.sectionSpacing) {
            PageHeader(
                title: "Cleanup",
                subtitle: "Preview removable Homebrew caches and old versions before running cleanup."
            ) {
                ActionButton(title: "Preview cleanup", systemImage: "arrow.clockwise") {
                    Task { await model.loadPreview() }
                }
                .disabled(model.isPreviewing || isRunning)

                ActionButton(title: "Run cleanup", systemImage: "trash", variant: .primary) {
                    confirmation = ConfirmationRequest(
                        title: "Run Homebrew cleanup?",
                        message: "Brewwery will run",
                        command: "brew cleanup",
                        note: "This can remove old versions, caches, logs, and broken links listed in the preview.",
                        confirmLabel: "Run cleanup"
                    )
                }
                .disabled(!model.canRunCleanup || model.isPreviewing || isRunning)
            }

            policyNote
            content
        }
        .confirmation($confirmation, isWorking: isRunning) { _ in
            Task { await brewwery.runCleanup() }
        }
    }

    private var policyNote: some View {
        BrewweryCard {
            (
                Text("Brewwery always runs ")
                    + Text("brew cleanup -n").font(BrewweryFont.mono).foregroundColor(BrewweryColor.foreground)
                    + Text(" first. The actual cleanup command is only available after a preview and requires confirmation.")
            )
            .font(BrewweryFont.body)
            .foregroundStyle(BrewweryColor.mutedForeground)
            .lineSpacing(4)
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private var content: some View {
        if model.isPreviewing {
            StatePanel(title: "Loading cleanup preview...", kind: .loading)
        } else if let error = model.error {
            if error.code == .homebrewNotFound {
                HomebrewNotFoundPanel()
            } else {
                StatePanel(
                    title: error.code == .cleanupRunFailed ? "Cleanup failed" : "Failed to preview cleanup",
                    kind: .error
                ) {
                    ErrorDescriptionView(error: error)
                } action: {
                    Button("Retry preview") { Task { await model.loadPreview() } }.brewweryButton()
                }
            }
        } else {
            OperationProgressPanel()

            if let result = model.result {
                StatePanel(title: "Cleanup completed") {
                    VStack(spacing: Metrics.tightSpacing) {
                        Text("\(result.removedItems ?? 0) removal operations reported.")
                        if let freed = result.freedSpace {
                            Text("Freed space: \(freed)")
                        }
                        if let output = [result.stdout, result.stderr].compactMap({ $0 }).joined(separator: "\n").nilIfBlank {
                            OutputDisclosure(label: "Show details", content: output)
                        }
                    }
                }
            } else if let preview = model.preview {
                if preview.items.isEmpty {
                    StatePanel(title: "Nothing to clean") {
                        if let raw = preview.rawOutput {
                            OutputDisclosure(label: "Show details", content: raw)
                        }
                    }
                } else {
                    previewCard(preview)
                }
            } else {
                StatePanel(title: "No cleanup preview yet")
            }
        }
    }

    private func previewCard(_ preview: CleanupPreview) -> some View {
        VStack(alignment: .leading, spacing: Metrics.rowSpacing) {
            BrewweryHeaderCard {
                HStack {
                    Text("Preview Results")
                        .font(BrewweryFont.panelTitle)
                        .foregroundStyle(BrewweryColor.foreground)
                    Spacer()
                    Text("\(preview.items.count) items" + (preview.totalSize.map { " · \($0)" } ?? ""))
                        .font(BrewweryFont.body)
                        .foregroundStyle(BrewweryColor.mutedForeground)
                }
            } content: {
                VStack(alignment: .leading, spacing: Metrics.rowSpacing) {
                    BrewweryTable(
                        accessibilityLabel: "Cleanup preview",
                        items: preview.items,
                        columns: [
                            TableColumnSpec("Item", width: .flexible(minimum: 160, weight: 1.4)) { item in
                                Text(item.name ?? "Unknown item")
                                    .font(BrewweryFont.controlLabel)
                                    .foregroundStyle(BrewweryColor.foreground)
                                    .lineLimit(1)
                            },
                            TableColumnSpec("Kind", width: .fixed(128)) { item in
                                BrewweryBadge(text: item.kind?.displayName ?? "unknown")
                            },
                            TableColumnSpec("Size", width: .fixed(128)) { item in
                                Text(item.size ?? "Unknown")
                                    .font(BrewweryFont.body)
                                    .foregroundStyle(BrewweryColor.mutedForeground)
                            },
                            TableColumnSpec("Path", width: .flexible(minimum: 220, weight: 2)) { item in
                                Text(item.path ?? "Unknown path")
                                    .font(BrewweryFont.body)
                                    .foregroundStyle(BrewweryColor.mutedForeground)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                        ],
                        rowHeight: 52,
                        maxHeight: 420,
                        onActivate: { _ in }
                    )

                    if let raw = preview.rawOutput {
                        OutputDisclosure(label: "Show details", content: raw)
                    }
                }
            }
        }
    }
}
