import Foundation

/// A problem report the user reads in full and sends themselves.
///
/// Brewwery has no reporting server and never sends anything in the background. A report is
/// plain text that the user reviews, then hands to their browser as a pre-filled GitHub issue,
/// to their mail client, or to the clipboard. Home-directory paths are masked before any of
/// that, so a report never carries the account name unless the user types it.
public struct ProblemReport: Sendable, Equatable {
    /// One row of the environment table: `Brewwery 1.1.0`, `macOS 15.3 (24D60)`, …
    public struct DiagnosticItem: Sendable, Equatable {
        public let label: String
        public let value: String

        public init(_ label: String, _ value: String) {
            self.label = label
            self.value = value
        }
    }

    /// The operation a "Report this failure" button was pressed on.
    public struct Failure: Sendable, Equatable {
        public var command: String
        /// "failed", "timed out" or "cancelled".
        public var result: String
        public var errorCode: String?
        public var errorMessage: String?
        /// Combined stdout and stderr, in the order Homebrew wrote them.
        public var output: String

        public init(command: String, result: String, errorCode: String?, errorMessage: String?, output: String) {
            self.command = command
            self.result = result
            self.errorCode = errorCode
            self.errorMessage = errorMessage
            self.output = output
        }
    }

    public var description: String
    public var diagnostics: [DiagnosticItem]
    public var failure: Failure?
    public var includeDiagnostics = true
    public var includeOutput = true

    public init(description: String = "", diagnostics: [DiagnosticItem], failure: Failure? = nil) {
        self.description = description
        self.diagnostics = diagnostics
        self.failure = failure
    }

    /// Where reports go. The repository is also the only github.com path on the link allowlist.
    public static let issuesURL = "https://github.com/brewwery/brewwery/issues/new"
    public static let supportAddress = "pint@brewwery.com"

    /// The most output a report carries. Homebrew's useful part is almost always at the end.
    public static let outputLineLimit = 60

    /// GitHub rejects very long pre-filled URLs; staying under this keeps "New issue" opening.
    public static let issueURLLimit = 7_500
    /// Mail clients vary; this is comfortably inside all of the common ones.
    public static let mailURLLimit = 6_000

    // MARK: - Text

    public var title: String {
        if let failure {
            return "\(failure.result.capitalized): \(Self.redact(failure.command))"
        }
        let firstLine = description
            .split(separator: "\n", omittingEmptySubsequences: true)
            .first
            .map { $0.trimmingCharacters(in: .whitespaces) } ?? ""
        guard !firstLine.isEmpty else { return "Problem report" }
        return firstLine.count > 80 ? String(firstLine.prefix(79)) + "…" : firstLine
    }

    /// The report as Markdown — readable as plain text in a mail client, rendered on GitHub.
    ///
    /// - Parameter outputLines: how many of the last output lines to keep. `nil` uses
    ///   `outputLineLimit`; smaller values are what the URL builders fall back to.
    public func markdown(outputLines: Int? = nil) -> String {
        var sections: [String] = []

        let trimmed = description.trimmingCharacters(in: .whitespacesAndNewlines)
        sections.append("### What happened\n\n" + (trimmed.isEmpty ? "_No description given._" : Self.redact(trimmed)))

        if let failure {
            var lines = ["### Failed operation", ""]
            lines.append("- Command: `\(Self.redact(failure.command))`")
            lines.append("- Result: \(failure.result)" + (failure.errorCode.map { " (`\($0)`)" } ?? ""))
            if let message = failure.errorMessage, !message.isEmpty {
                lines.append("- Message: \(Self.redact(message))")
            }

            let output = Self.tail(of: Self.redact(failure.output), lines: outputLines ?? Self.outputLineLimit)
            if includeOutput, !output.isEmpty {
                let fence = output.contains("```") ? "~~~" : "```"
                lines.append("")
                lines.append("<details><summary>Homebrew output (last lines)</summary>")
                lines.append("")
                lines.append(fence)
                lines.append(output)
                lines.append(fence)
                lines.append("")
                lines.append("</details>")
            }
            sections.append(lines.joined(separator: "\n"))
        }

        if includeDiagnostics, !diagnostics.isEmpty {
            let rows = diagnostics.map { "| \($0.label) | \(Self.redact($0.value)) |" }
            sections.append((["### Environment", "", "| | |", "| --- | --- |"] + rows).joined(separator: "\n"))
        }

        return sections.joined(separator: "\n\n") + "\n"
    }

    // MARK: - Destinations

    /// A "New issue" link with the title and body filled in.
    ///
    /// When the whole report does not fit, output lines are dropped from the top until it
    /// does. `isTruncated` tells the caller to put the complete report on the clipboard too.
    public func githubIssueURL() -> (url: URL, isTruncated: Bool) {
        fitting(limit: Self.issueURLLimit) { body in
            var components = URLComponents(string: Self.issuesURL)!
            components.queryItems = [
                URLQueryItem(name: "title", value: title),
                URLQueryItem(name: "labels", value: "bug"),
                URLQueryItem(name: "body", value: body)
            ]
            return components.url!
        }
    }

    /// A `mailto:` link to the support address with the report as its body.
    public func mailURL() -> (url: URL, isTruncated: Bool) {
        fitting(limit: Self.mailURLLimit) { body in
            var components = URLComponents()
            components.scheme = "mailto"
            components.path = Self.supportAddress
            components.queryItems = [
                URLQueryItem(name: "subject", value: "Brewwery: \(title)"),
                URLQueryItem(name: "body", value: body)
            ]
            return components.url!
        }
    }

    private func fitting(limit: Int, build: (String) -> URL) -> (url: URL, isTruncated: Bool) {
        var lines = Self.outputLineLimit
        while true {
            let url = build(markdown(outputLines: lines))
            if url.absoluteString.count <= limit { return (url, lines < Self.outputLineLimit) }
            if lines == 0 { break }
            lines = lines > 10 ? lines - 10 : 0
        }

        // Even without output it is too long — the description itself is enormous. Cut it,
        // and say so in the report so nobody mistakes it for the whole story.
        var report = self
        report.includeOutput = false
        var keep = max(200, description.count / 2)
        while keep > 0 {
            report.description = String(description.prefix(keep)) + "\n\n_[Trimmed to fit the link — the full report is on the clipboard.]_"
            let url = build(report.markdown(outputLines: 0))
            if url.absoluteString.count <= limit { return (url, true) }
            keep /= 2
        }
        return (build(""), true)
    }

    // MARK: - Helpers

    /// Replaces home-directory paths (`/Users/alex/…`) with `~/…`.
    public static func redact(_ text: String) -> String {
        var result = text
        let home = NSHomeDirectory()
        if home.hasPrefix("/Users/"), home.count > "/Users/".count {
            result = result.replacingOccurrences(of: home, with: "~")
        }
        // Other accounts' homes, or a home the process sees differently. `/Users/Shared` is
        // not anyone's home, and hiding it would make paths harder to read, not safer.
        return result.replacingOccurrences(
            of: #"/Users/(?!Shared(?:/|$|\s))[^/\s"'`]+"#,
            with: "~",
            options: .regularExpression
        )
    }

    static func tail(of text: String, lines count: Int) -> String {
        guard count > 0 else { return "" }
        let lines = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: "\n", omittingEmptySubsequences: false)
        return lines.suffix(count).joined(separator: "\n")
    }
}

/// Facts about the Mac a report needs and diagnostics lacked: the macOS build and model.
public enum SystemFacts {
    /// `15.3.1 (24D70)`.
    public static var macOSVersion: String {
        let version = ProcessInfo.processInfo.operatingSystemVersion
        let number = version.patchVersion == 0
            ? "\(version.majorVersion).\(version.minorVersion)"
            : "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"
        guard let build = sysctlString("kern.osversion") else { return number }
        return "\(number) (\(build))"
    }

    /// `Mac14,2`. The identifier only — no serial number, no name.
    public static var hardwareModel: String {
        sysctlString("hw.model") ?? "unknown"
    }

    /// The architecture this process runs as, which can differ from the Mac's under Rosetta.
    public static var processArchitecture: String {
        #if arch(arm64)
        return "arm64"
        #elseif arch(x86_64)
        return "x86_64"
        #else
        return "unknown"
        #endif
    }

    private static func sysctlString(_ name: String) -> String? {
        var size = 0
        guard sysctlbyname(name, nil, &size, nil, 0) == 0, size > 0 else { return nil }
        var buffer = [CChar](repeating: 0, count: size)
        guard sysctlbyname(name, &buffer, &size, nil, 0) == 0 else { return nil }
        return buffer.withUnsafeBufferPointer { String(cString: $0.baseAddress!) }
    }
}
