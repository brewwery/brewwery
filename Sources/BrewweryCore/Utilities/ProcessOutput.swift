import Foundation

/// Buffered result of a finished command (`CommandOutput` in `runner.rs`).
///
/// `stdout` and `stderr` are trimmed exactly as the Rust runner trimmed them, because
/// downstream parsers and UI copy were written against trimmed text.
public struct ProcessOutput: Sendable, Hashable {
    public let stdout: String
    public let stderr: String
    public let statusCode: Int32?
    public let success: Bool

    public init(stdout: String, stderr: String, statusCode: Int32?, success: Bool) {
        self.stdout = stdout
        self.stderr = stderr
        self.statusCode = statusCode
        self.success = success
    }
}

extension ProcessOutput {
    /// Synchronous capture, used only for the short-lived probes that must run before any
    /// actor is available: `brew --version` during path validation and `which brew`.
    static func capture(
        executablePath: String,
        arguments: [String],
        environment: [String: String]
    ) throws(BrewweryError) -> ProcessOutput {
        let child = try ChildProcess.spawn(
            executablePath: executablePath,
            arguments: arguments,
            environment: environment
        )
        // Both pipes are drained concurrently so a chatty stderr cannot fill its buffer and
        // block the child while this thread is still reading stdout.
        let group = DispatchGroup()
        nonisolated(unsafe) var outputData = Data()
        nonisolated(unsafe) var errorData = Data()

        DispatchQueue.global().async(group: group) {
            outputData = child.standardOutput.readDataToEndOfFile()
        }
        DispatchQueue.global().async(group: group) {
            errorData = child.standardError.readDataToEndOfFile()
        }
        group.wait()

        let status = child.waitForExitBlocking()

        return ProcessOutput(
            stdout: String(decoding: outputData, as: UTF8.self).trimmed,
            stderr: String(decoding: errorData, as: UTF8.self).trimmed,
            statusCode: status,
            success: status == 0
        )
    }
}

extension String {
    /// Rust's `str::trim()` — whitespace and newlines at both ends.
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
