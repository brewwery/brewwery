import AppKit
import BrewweryCore
import SwiftUI

/// A report the "Report a problem" window is editing.
struct ProblemReportDraft: Identifiable {
    let id = UUID()
    /// "Report a problem" or "Report this failure".
    let heading: LocalizedStringResource
    var report: ProblemReport
}

extension AppEnvironment {
    /// Everything a bug report and "Copy diagnostics" say about this Mac and this install.
    /// No package names, no paths outside Homebrew's own, no identifiers.
    var diagnosticItems: [ProblemReport.DiagnosticItem] {
        [
            .init("Brewwery", "\(AppInfo.version) (\(AppInfo.build)) · \(AppInfo.channel)"),
            .init("macOS", SystemFacts.macOSVersion),
            .init("Mac", "\(SystemFacts.hardwareModel) · \(SystemFacts.processArchitecture)"),
            .init("Homebrew", system.info?.version ?? "not detected"),
            .init("Homebrew path", system.info?.path ?? system.detection?.path ?? "not detected"),
            .init("Homebrew prefix", system.info?.prefix ?? "unknown"),
            .init("Homebrew architecture", system.info?.architecture.rawValue ?? "unknown"),
            .init(
                "Library",
                "\(library.formulae.count) formulae, \(library.casks.count) casks, "
                    + "\(services.services.count) services, \(updates.count) outdated"
            )
        ]
    }

    /// Opens the report window with nothing but the environment filled in.
    func reportProblem() {
        state.problemReport = ProblemReportDraft(
            heading: "Report a problem",
            report: ProblemReport(diagnostics: diagnosticItems)
        )
    }

    /// Opens the report window for the operation the progress panel is showing.
    func reportFailure(of progress: OperationProgress) {
        let output = progress.lines.map(\.text).joined(separator: "\n")
        state.problemReport = ProblemReportDraft(
            heading: "Report this failure",
            report: ProblemReport(
                diagnostics: diagnosticItems,
                failure: .init(
                    command: progress.command,
                    result: progress.status.displayName,
                    errorCode: progress.error?.code.rawValue,
                    errorMessage: progress.error?.friendlyMessage,
                    output: output.isEmpty ? progress.stdout + "\n" + progress.stderr : output
                )
            )
        )
    }

    /// Opens the report window for a failed entry in History, for when the progress panel
    /// has long been dismissed.
    func reportFailure(of entry: HistoryEntry) {
        let output = [entry.stdout, entry.stderr, entry.error?.raw]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
        state.problemReport = ProblemReportDraft(
            heading: "Report this failure",
            report: ProblemReport(
                diagnostics: diagnosticItems,
                failure: .init(
                    command: entry.command ?? entry.title,
                    result: entry.status.rawValue,
                    errorCode: entry.error?.code.rawValue,
                    errorMessage: entry.error?.friendlyMessage,
                    output: output
                )
            )
        )
    }
}
