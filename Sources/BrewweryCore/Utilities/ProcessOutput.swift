import Darwin
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
        environment: [String: String],
        timeoutSeconds: Double = 10,
        maximumBytes: Int = 1_000_000
    ) throws(BrewweryError) -> ProcessOutput {
        let child = try ChildProcess.spawn(
            executablePath: executablePath,
            arguments: arguments,
            environment: environment
        )
        // Both pipes are drained concurrently so a chatty stderr cannot fill its buffer and
        // block the child while this thread is still reading stdout.
        let group = DispatchGroup()
        nonisolated(unsafe) var outputData = PipeReader.Capture()
        nonisolated(unsafe) var errorData = PipeReader.Capture()
        nonisolated(unsafe) var status: Int32 = -1

        DispatchQueue.global().async(group: group) {
            outputData = PipeReader.capture(child.standardOutput, limit: maximumBytes) { child.signalGroup(SIGKILL) }
        }
        DispatchQueue.global().async(group: group) {
            errorData = PipeReader.capture(child.standardError, limit: maximumBytes) { child.signalGroup(SIGKILL) }
        }
        DispatchQueue.global().async(group: group) { status = child.waitForExitBlocking() }
        if group.wait(timeout: .now() + timeoutSeconds) == .timedOut {
            child.signalGroup(SIGKILL)
            group.wait()
            throw BrewweryError(code: .operationTimeout, message: "Homebrew path validation timed out.")
        }
        guard !outputData.exceededLimit, !errorData.exceededLimit else {
            throw BrewweryError(code: .brewCommandFailed, message: "Homebrew path validation produced too much output.")
        }

        return ProcessOutput(
            stdout: outputData.text,
            stderr: errorData.text,
            statusCode: status,
            success: status == 0
        )
    }
}

extension String {
    /// Rust's `str::trim()` — whitespace and newlines at both ends.
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
