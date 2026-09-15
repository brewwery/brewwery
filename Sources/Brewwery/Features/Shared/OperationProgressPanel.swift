import BrewweryCore
import SwiftUI

/// `components/ui/operation-progress-panel.tsx` — the live output card shown while a
/// mutating Homebrew command runs, with a confirmation-gated Cancel button.
struct OperationProgressPanel: View {
    @Environment(AppEnvironment.self) private var brewwery
    @State private var cancelRequest: ConfirmationRequest?

    var body: some View {
        if let progress = brewwery.operations.progress {
            content(progress)
                .confirmation($cancelRequest, isWorking: brewwery.operations.isCancelling) { _ in
                    Task { await brewwery.operations.cancel() }
                }
        }
    }

    private func content(_ progress: OperationProgress) -> some View {
        BrewweryCard {
            VStack(alignment: .leading, spacing: Metrics.rowSpacing) {
                header(progress)
                metadata(progress)
                progressBar(progress)
                output(progress)

                if let error = progress.error {
                    Text(error.friendlyMessage)
                        .font(BrewweryFont.body)
                        .foregroundStyle(progress.status == .cancelled ? BrewweryColor.accent : BrewweryColor.danger)
                }
            }
        }
    }

    private func header(_ progress: OperationProgress) -> some View {
        HStack(alignment: .center, spacing: Metrics.rowSpacing) {
            StatusGlyph(status: progress.status)

            VStack(alignment: .leading, spacing: 2) {
                Text(title(for: progress.status))
                    .font(BrewweryFont.controlLabel)
                    .foregroundStyle(BrewweryColor.foreground)
                Text(progress.command)
                    .font(BrewweryFont.monoCaption)
                    .foregroundStyle(BrewweryColor.mutedForeground)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer(minLength: Metrics.tightSpacing)

            if progress.status == .running {
                ActionButton(
                    title: brewwery.operations.isCancelling ? "Cancelling..." : "Cancel operation",
                    systemImage: "stop.fill",
                    height: Metrics.compactControlHeight
                ) {
                    cancelRequest = ConfirmationRequest(
                        title: "Cancel this Homebrew operation?",
                        message: "Brewwery will stop the active Homebrew process. The package may require a retry or Homebrew cleanup afterward.",
                        confirmLabel: "Cancel operation"
                    )
                }
                .disabled(brewwery.operations.isCancelling)
            } else {
                Button("Dismiss") { brewwery.operations.clear() }
                    .brewweryButton(.ghost, height: Metrics.compactControlHeight)
            }
        }
    }

    private func metadata(_ progress: OperationProgress) -> some View {
        HStack(alignment: .top, spacing: Metrics.cardSpacing) {
            MetaColumn(label: "Target", value: progress.target ?? progress.command)
            MetaColumn(label: "Work", value: summary(progress).work)
            MetaColumn(label: "Safety timeout", value: "\(progress.timeoutSeconds / 60) min")
            MetaColumn(label: "Operation ID", value: shortID(progress.id), monospaced: true)
        }
        .padding(Metrics.rowSpacing)
        .background(BrewweryColor.background.opacity(0.45))
        .clipShape(RoundedRectangle(cornerRadius: Metrics.controlRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Metrics.controlRadius, style: .continuous)
                .strokeBorder(BrewweryColor.border, lineWidth: 1)
        )
    }

    private func progressBar(_ progress: OperationProgress) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(summary(progress).status)
                Spacer()
                Text(progress.status.displayName)
            }
            .font(BrewweryFont.caption)
            .foregroundStyle(BrewweryColor.mutedForeground)

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(BrewweryColor.muted)
                    Capsule()
                        .fill(barColor(progress.status))
                        .frame(width: geometry.size.width * fraction(progress))
                        .animation(.easeOut(duration: 0.25), value: fraction(progress))
                }
            }
            .frame(height: 6)
            .accessibilityElement()
            .accessibilityLabel("Operation progress")
            .accessibilityValue(summary(progress).status)
        }
    }

    private func output(_ progress: OperationProgress) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if progress.lines.isEmpty {
                        Text("Waiting for Homebrew output...")
                            .font(BrewweryFont.monoCaption)
                            .foregroundStyle(BrewweryColor.mutedForeground)
                    }
                    ForEach(progress.lines) { line in
                        Text(line.text)
                            .font(BrewweryFont.monoCaption)
                            .foregroundStyle(
                                line.stream == .stderr ? BrewweryColor.warning : BrewweryColor.mutedForeground
                            )
                            .lineSpacing(3)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .id(line.id)
                    }
                }
                .padding(Metrics.rowSpacing)
            }
            .frame(height: 192)
            .background(BrewweryColor.background.opacity(0.7))
            .clipShape(RoundedRectangle(cornerRadius: Metrics.controlRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Metrics.controlRadius, style: .continuous)
                    .strokeBorder(BrewweryColor.border, lineWidth: 1)
            )
            .onChange(of: progress.lines.count) {
                guard let last = progress.lines.last else { return }
                withAnimation(.easeOut(duration: 0.15)) { proxy.scrollTo(last.id, anchor: .bottom) }
            }
        }
    }

    // MARK: - Presentation helpers

    private func title(for status: OperationStatus) -> String {
        switch status {
        case .running: "Running Homebrew operation"
        case .success: "Operation completed"
        case .cancelled: "Operation cancelled"
        case .timedOut: "Operation timed out"
        case .failed: "Operation failed"
        }
    }

    private func barColor(_ status: OperationStatus) -> Color {
        switch status {
        case .cancelled: BrewweryColor.accent
        case .failed, .timedOut: BrewweryColor.danger
        case .success: BrewweryColor.success
        case .running: BrewweryColor.accent
        }
    }

    /// `progressSummary()` — Homebrew gives no percentage, so the bar advances with each
    /// `==>` phase and is capped well short of full until the command actually finishes.
    private func fraction(_ progress: OperationProgress) -> Double {
        guard progress.status == .running else { return 1 }
        let phases = (progress.stdout + "\n" + progress.stderr)
            .split(separator: "\n", omittingEmptySubsequences: false)
            .count { $0.hasPrefix("==>") }
        return min(0.85, max(0.12, Double(phases) * 0.12))
    }

    private func summary(_ progress: OperationProgress) -> (work: String, status: String) {
        let text = progress.stdout + "\n" + progress.stderr
        let queued = queuedPackageCount(in: text)

        let work = switch progress.kind {
        case .service: "Service action"
        case .cleanup: "Cleanup run"
        default: queued == 1 ? "1 package queued" : "\(queued) packages queued"
        }

        let status: String = switch progress.status {
        case .success:
            switch progress.kind {
            case .service: "Service action completed"
            case .cleanup: "Cleanup completed"
            default: queued == 1 ? "1 of 1 package completed" : "\(queued) packages completed"
            }
        case .failed: "Stopped with an error"
        case .cancelled: "Cancelled by user"
        case .timedOut: "Stopped by safety timeout"
        case .running:
            switch progress.kind {
            case .service: "Running service action"
            case .cleanup: "Running Homebrew cleanup"
            default: queued == 1 ? "Processing 1 package" : "Processing \(queued) packages"
            }
        }

        return (work, status)
    }

    /// `parseQueuedPackageCount()` — "Upgrading N outdated packages" is the only count
    /// Homebrew reports up front.
    private func queuedPackageCount(in text: String) -> Int {
        guard let range = text.range(of: #"Upgrading\s+(\d+)\s+outdated package"#, options: [.regularExpression, .caseInsensitive]) else {
            return 1
        }
        let digits = text[range].filter(\.isNumber)
        return Int(digits) ?? 1
    }

    private func shortID(_ id: UUID) -> String {
        String(id.uuidString.split(separator: "-").first ?? "")
    }
}

private struct StatusGlyph: View {
    let status: OperationStatus
    @State private var isSpinning = false

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 14))
            .foregroundStyle(tint)
            .rotationEffect(.degrees(isSpinning ? 360 : 0))
            .animation(
                status == .running ? .linear(duration: 1).repeatForever(autoreverses: false) : .default,
                value: isSpinning
            )
            .onAppear { isSpinning = status == .running }
            .onChange(of: status) { isSpinning = status == .running }
    }

    private var symbol: String {
        switch status {
        case .running: "arrow.triangle.2.circlepath"
        case .success: "checkmark.circle"
        default: "xmark.circle"
        }
    }

    private var tint: Color {
        switch status {
        case .running: BrewweryColor.accent
        case .success: BrewweryColor.success
        case .cancelled: BrewweryColor.accent
        case .failed, .timedOut: BrewweryColor.danger
        }
    }
}

private struct MetaColumn: View {
    let label: String
    let value: String
    var monospaced = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(BrewweryFont.caption)
                .foregroundStyle(BrewweryColor.mutedForeground)
            Text(value)
                .font(monospaced ? BrewweryFont.monoCaption : BrewweryFont.captionEmphasis)
                .foregroundStyle(BrewweryColor.foreground)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
