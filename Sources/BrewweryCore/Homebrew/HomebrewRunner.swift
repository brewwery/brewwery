import Darwin
import Foundation

/// Executes typed Homebrew commands.
///
/// Two modes, matching the two execution paths the legacy app had:
///
/// * `run(_:)` buffers the whole output and is used for reads and short mutations;
/// * `stream(_:kind:)` yields live stdout/stderr and supports cancellation, and is used for
///   install, uninstall, upgrade, service actions and cleanup.
///
/// The runner is an `actor`, so no `Process`, pipe or termination bookkeeping is ever touched
/// from two tasks at once, and nothing here runs on the main actor.
public actor HomebrewRunner {
    /// Grace period between SIGTERM and SIGKILL (`FORCE_KILL_DELAY_MS`).
    static let forceKillDelay = Duration.seconds(5)

    private let detector: HomebrewDetector
    /// The environment every `brew` invocation receives. Injectable so failure modes such as
    /// an unreachable network can be reproduced deliberately.
    private let environment: [String: String]
    private var activeChildren: [UUID: ChildProcess] = [:]

    public init(detector: HomebrewDetector, environment: [String: String] = HomebrewEnvironment.values()) {
        self.detector = detector
        self.environment = environment
    }

    // MARK: - Buffered execution

    /// Runs a command and returns its output, failing on a non-zero exit status.
    ///
    /// Matches `run_brew_output`: a failed command raises `commandFailed(stderr)`, except for
    /// commands that tolerate a non-zero status (`brew doctor`).
    @discardableResult
    public func run(_ command: HomebrewCommand) async throws(BrewweryError) -> ProcessOutput {
        let output = try await runPermissive(command)
        guard output.success || command.toleratesNonZeroExit else {
            throw BrewweryError.commandFailed(output.stderr)
        }
        return output
    }

    /// Runs a command and returns its output regardless of exit status
    /// (`run_brew_output_permissive`).
    public func runPermissive(_ command: HomebrewCommand) async throws(BrewweryError) -> ProcessOutput {
        let arguments = try command.arguments()
        let executable = try await detector.executableURL()

        Log.homebrew.debug("run brew \(arguments.first ?? "", privacy: .public)")

        let child = try ChildProcess.spawn(
            executablePath: executable.path,
            arguments: arguments,
            environment: environment
        )

        async let outputText = Self.readToEnd(child.standardOutput)
        async let errorText = Self.readToEnd(child.standardError)
        let status = await child.waitForExit()

        return ProcessOutput(
            stdout: await outputText.trimmed,
            stderr: await errorText.trimmed,
            statusCode: status,
            success: status == 0
        )
    }

    /// `run_brew_with_fallback` — retries with a second command only when Homebrew rejects
    /// the first with "needless argument", which is how Homebrew 5 refuses `--json=v2` for
    /// `brew list`.
    public func run(
        _ command: HomebrewCommand,
        fallback: HomebrewCommand
    ) async throws(BrewweryError) -> ProcessOutput {
        do {
            return try await run(command)
        } catch {
            guard error.message.contains("needless argument") else { throw error }
            Log.homebrew.notice("Retrying with legacy JSON arguments")
            return try await run(fallback)
        }
    }

    // MARK: - Streaming execution

    /// Starts a streaming operation and returns its live event sequence.
    ///
    /// The returned stream finishes after exactly one terminal event (`completed` or
    /// `failed`). Cancelling the consuming task terminates the child process group, so a
    /// dropped stream can never leave `brew` running in the background.
    public func stream(
        _ command: HomebrewCommand,
        kind: OperationKind,
        id: UUID
    ) async throws(BrewweryError) -> AsyncStream<OperationEvent> {
        let arguments = try command.arguments()
        let executable = try await detector.executableURL()
        let displayCommand = command.displayCommand()

        let child = try ChildProcess.spawn(
            executablePath: executable.path,
            arguments: arguments,
            environment: environment
        )
        activeChildren[id] = child
        Log.process.info("Operation \(id.uuidString, privacy: .public) started: \(kind.rawValue, privacy: .public)")

        let collector = OutputCollector()

        return AsyncStream(bufferingPolicy: .unbounded) { continuation in
            continuation.yield(.started(at: Date()))

            let pump = Task.detached { [weak self] in
                async let outputDone: Void = Self.pump(
                    child.standardOutput,
                    stream: .stdout,
                    collector: collector,
                    continuation: continuation
                )
                async let errorDone: Void = Self.pump(
                    child.standardError,
                    stream: .stderr,
                    collector: collector,
                    continuation: continuation
                )
                _ = await (outputDone, errorDone)

                let status = await child.waitForExit()
                let captured = await collector.snapshot()
                let reason = await self?.terminationReason(for: id) ?? nil
                await self?.forget(id)

                continuation.yield(
                    Self.terminalEvent(
                        reason: reason,
                        status: status,
                        stdout: captured.stdout,
                        stderr: captured.stderr,
                        kind: kind,
                        displayCommand: displayCommand
                    )
                )
                continuation.finish()
            }

            let timeout = Task.detached { [weak self] in
                try? await Task.sleep(for: kind.timeout)
                guard !Task.isCancelled else { return }
                await self?.terminate(id, reason: .timeout)
            }

            continuation.onTermination = { termination in
                timeout.cancel()
                if case .cancelled = termination {
                    pump.cancel()
                    Task { await self.terminate(id, reason: .cancelled) }
                }
            }
        }
    }

    /// Requests cancellation of a running operation (`cancelOperation`).
    ///
    /// Returns whether a signal was actually delivered, so the UI can keep the Cancel button
    /// enabled if the operation had already finished.
    @discardableResult
    public func cancel(_ id: UUID) -> Bool {
        terminate(id, reason: .cancelled)
    }

    public func isRunning(_ id: UUID) -> Bool {
        activeChildren[id] != nil
    }

    // MARK: - Termination

    enum TerminationReason: Sendable {
        case cancelled
        case timeout
    }

    private var terminationReasons: [UUID: TerminationReason] = [:]

    private func terminationReason(for id: UUID) -> TerminationReason? {
        terminationReasons[id]
    }

    @discardableResult
    private func terminate(_ id: UUID, reason: TerminationReason) -> Bool {
        guard let child = activeChildren[id], terminationReasons[id] == nil, !child.hasTerminated else {
            return false
        }
        terminationReasons[id] = reason
        guard child.signalGroup(SIGTERM) else {
            terminationReasons[id] = nil
            return false
        }
        Log.process.notice("Operation \(id.uuidString, privacy: .public) terminating: \(String(describing: reason), privacy: .public)")

        // Escalate if the process group ignores SIGTERM.
        Task.detached {
            try? await Task.sleep(for: Self.forceKillDelay)
            guard !child.hasTerminated else { return }
            child.signalGroup(SIGKILL)
        }
        return true
    }

    private func forget(_ id: UUID) {
        activeChildren[id] = nil
        // The reason is read immediately before this call, so it can be released with it.
        terminationReasons[id] = nil
    }

    private static func terminalEvent(
        reason: TerminationReason?,
        status: Int32,
        stdout: String,
        stderr: String,
        kind: OperationKind,
        displayCommand: String
    ) -> OperationEvent {
        let trimmedOut = stdout.trimmed
        let trimmedError = stderr.trimmed

        if let reason {
            let timedOut = reason == .timeout
            let error = BrewweryError(
                code: timedOut ? .operationTimeout : .operationCancelled,
                message: timedOut
                    ? "\(displayCommand) exceeded its \(kind.timeoutDescription) safety timeout."
                    : "\(displayCommand) was cancelled.",
                raw: [trimmedOut, trimmedError].filter { !$0.isEmpty }.joined(separator: "\n").nilIfEmpty
            )
            return .failed(stdout: trimmedOut, stderr: trimmedError, statusCode: status, error: error, at: Date())
        }

        guard status != 0 else {
            return .completed(stdout: trimmedOut, stderr: trimmedError, statusCode: status, at: Date())
        }

        let error = BrewweryError(
            code: kind.failureCode,
            message: "\(displayCommand) failed with exit code \(status).",
            raw: (trimmedError.isEmpty ? trimmedOut : trimmedError).nilIfEmpty
        )
        return .failed(stdout: trimmedOut, stderr: trimmedError, statusCode: status, error: error, at: Date())
    }

    // MARK: - Pipe draining

    /// Drains one pipe, forwarding chunks as they arrive. Both pipes are drained
    /// concurrently so a chatty stderr can never block stdout and deadlock the child.
    private static func pump(
        _ handle: FileHandle,
        stream: OutputStream,
        collector: OutputCollector,
        continuation: AsyncStream<OperationEvent>.Continuation
    ) async {
        for await chunk in handle.textChunks {
            await collector.append(chunk, to: stream)
            continuation.yield(.output(stream: stream, chunk: chunk, at: Date()))
        }
    }

    private static func readToEnd(_ handle: FileHandle) async -> String {
        await withCheckedContinuation { continuation in
            DispatchQueue.global().async {
                let data = handle.readDataToEndOfFile()
                continuation.resume(returning: String(decoding: data, as: UTF8.self))
            }
        }
    }
}

// MARK: - Support

extension OperationKind {
    /// `errorFor()` — the failure code each operation family reports.
    var failureCode: BrewweryErrorCode {
        switch self {
        case .install: .packageInstallFailed
        case .uninstall: .packageUninstallFailed
        case .service: .serviceCommandFailed
        case .cleanup: .cleanupRunFailed
        case .upgrade: .brewCommandFailed
        }
    }
}

/// Accumulates bounded stdout/stderr for one streaming operation.
private actor OutputCollector {
    private var stdout = BoundedOutput(limit: BoundedOutput.operationLimit)
    private var stderr = BoundedOutput(limit: BoundedOutput.operationLimit)

    func append(_ chunk: String, to stream: OutputStream) {
        switch stream {
        case .stdout: stdout.append(chunk)
        case .stderr: stderr.append(chunk)
        }
    }

    func snapshot() -> (stdout: String, stderr: String) {
        (stdout.text, stderr.text)
    }
}

extension FileHandle {
    /// Chunks of decoded text as they arrive, finishing at EOF.
    var textChunks: AsyncStream<String> {
        AsyncStream(bufferingPolicy: .unbounded) { continuation in
            readabilityHandler = { handle in
                let data = handle.availableData
                guard !data.isEmpty else {
                    handle.readabilityHandler = nil
                    continuation.finish()
                    return
                }
                continuation.yield(String(decoding: data, as: UTF8.self))
            }
            continuation.onTermination = { [weak self] _ in
                self?.readabilityHandler = nil
            }
        }
    }
}

extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
