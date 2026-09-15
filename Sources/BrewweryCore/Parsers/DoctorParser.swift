import Foundation

/// Ports `doctor.rs` parsing.
///
/// `brew doctor` emits blocks that start with `Warning: <title>` and continue until a blank
/// line or the next warning. Brewwery keeps that structure instead of dumping raw terminal
/// output, so each diagnostic can be rendered as its own card.
public enum DoctorParser {
    public static func parse(_ output: String) -> [DoctorDiagnostic] {
        var diagnostics: [DoctorDiagnostic] = []
        var currentTitle: String?
        var currentLines: [String] = []

        func flush() {
            guard let title = currentTitle else { return }
            let message = currentLines.joined(separator: "\n").trimmed
            diagnostics.append(
                DoctorDiagnostic(
                    severity: .warning,
                    title: title,
                    message: message,
                    raw: message.isEmpty ? title : "Warning: \(title)\n\(message)"
                )
            )
            currentTitle = nil
            currentLines = []
        }

        for line in output.split(separator: "\n", omittingEmptySubsequences: false) {
            if let title = line.dropPrefixIfPresent("Warning: ") {
                flush()
                currentTitle = title.trimmed
            } else if line.trimmed.isEmpty {
                if currentTitle != nil, !currentLines.isEmpty { flush() }
            } else if currentTitle != nil {
                currentLines.append(String(line))
            }
        }

        flush()
        return diagnostics
    }

    /// A run counts as healthy only when there are no diagnostics *and* Homebrew said so.
    public static func makeResult(rawOutput: String) -> DoctorResult {
        let diagnostics = parse(rawOutput)
        return DoctorResult(
            healthy: diagnostics.isEmpty && rawOutput.lowercased().contains("ready to brew"),
            diagnostics: diagnostics,
            rawOutput: rawOutput.isEmpty ? nil : rawOutput
        )
    }
}
