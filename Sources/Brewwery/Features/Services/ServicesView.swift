import BrewweryCore
import SwiftUI

/// `pages/services.tsx` — every action is confirmation-gated, and per-row buttons are
/// disabled when they would be a no-op.
struct ServicesView: View {
    @Environment(AppEnvironment.self) private var brewwery

    @State private var confirmation: ConfirmationRequest?
    @State private var pending: (action: ServiceAction, name: String)?

    private var model: ServicesModel { brewwery.services }
    private var isBusy: Bool { model.isLoading || brewwery.operations.isRunning }

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.sectionSpacing) {
            PageHeader(
                title: "Services",
                subtitle: "Inspect and manage Homebrew services with explicit confirmation."
            ) {
                ActionButton(title: "Refresh", systemImage: "arrow.clockwise") {
                    Task { await model.refresh() }
                }
                .disabled(isBusy)
            }

            summary
            content
        }
        .task { if model.services.isEmpty { await model.refresh() } }
        .confirmation($confirmation, isWorking: brewwery.operations.isRunning) { _ in
            Task {
                guard let pending else { return }
                await brewwery.performServiceAction(pending.action, on: pending.name)
                self.pending = nil
            }
        }
    }

    private var summary: some View {
        HStack(spacing: Metrics.cardSpacing) {
            SummaryCard(label: "Total services", value: model.services.count)
            SummaryCard(label: "Running", value: model.count(of: .started))
            SummaryCard(label: "Stopped", value: model.count(of: .stopped))
            SummaryCard(label: "Errors", value: model.count(of: .error))
        }
    }

    @ViewBuilder
    private var content: some View {
        if model.isLoading {
            StatePanel(title: "Loading services...", kind: .loading)
        } else if let error = model.error {
            if error.code == .homebrewNotFound {
                HomebrewNotFoundPanel()
            } else {
                StatePanel(title: "Failed to load services", kind: .error) {
                    ErrorDescriptionView(error: error)
                } action: {
                    Button("Retry") { Task { await model.refresh() } }.brewweryButton()
                }
            }
        } else {
            OperationProgressPanel()

            if model.services.isEmpty {
                StatePanel(title: "No Homebrew services found")
            } else {
                table
            }
        }
    }

    private var table: some View {
        BrewweryTable(
            accessibilityLabel: "Homebrew services",
            items: model.services,
            columns: [
                TableColumnSpec("Service", width: .flexible(minimum: 150, weight: 1.6)) { service in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(service.name)
                            .font(BrewweryFont.controlLabel)
                            .foregroundStyle(BrewweryColor.foreground)
                        if let command = service.command {
                            Text(command)
                                .font(BrewweryFont.caption)
                                .foregroundStyle(BrewweryColor.mutedForeground)
                        }
                    }
                    .lineLimit(1)
                    .truncationMode(.middle)
                },
                TableColumnSpec("Status", width: .fixed(128)) { service in
                    ServiceStatusBadge(status: service.status)
                },
                TableColumnSpec("User", width: .fixed(120)) { service in
                    Text(service.user ?? "Unknown")
                        .font(BrewweryFont.body)
                        .foregroundStyle(BrewweryColor.mutedForeground)
                        .lineLimit(1)
                },
                TableColumnSpec("File", width: .flexible(minimum: 150, weight: 1.6)) { service in
                    Text(service.file ?? "No launch agent file")
                        .font(BrewweryFont.body)
                        .foregroundStyle(BrewweryColor.mutedForeground)
                        .lineLimit(1)
                        .truncationMode(.middle)
                },
                TableColumnSpec("Actions", width: .fixed(252), alignment: .trailing) { service in
                    HStack(spacing: Metrics.tightSpacing) {
                        actionButton(.start, for: service, disabledWhen: service.status == .started)
                        actionButton(.stop, for: service, disabledWhen: service.status == .stopped)
                        actionButton(.restart, for: service, disabledWhen: false)
                    }
                }
            ],
            rowHeight: 64,
            maxHeight: 560,
            onActivate: { _ in }
        )
    }

    private func actionButton(
        _ action: ServiceAction,
        for service: BrewService,
        disabledWhen isDisabled: Bool
    ) -> some View {
        Button(action.rawValue.capitalized) {
            pending = (action, service.name)
            confirmation = ConfirmationRequest(
                title: "\(action.rawValue.capitalized) \(service.name)?",
                message: "Brewwery will run",
                command: HomebrewCommand.service(action: action, name: service.name).displayCommand(),
                confirmLabel: action.rawValue.capitalized
            )
        }
        .brewweryButton(.secondary, height: Metrics.compactControlHeight)
        .disabled(isDisabled || brewwery.operations.isRunning)
    }
}
