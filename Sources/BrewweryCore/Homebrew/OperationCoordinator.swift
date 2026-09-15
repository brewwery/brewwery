import Foundation
import Observation

/// Live state of the operation the progress panel is showing.
@MainActor
@Observable
public final class OperationProgress {
    public let id: UUID
    public let kind: OperationKind
    public let command: String
    public let target: String?
    public let timeoutSeconds: Int

    public internal(set) var status: OperationStatus = .running
    public internal(set) var stdout: String = ""
    public internal(set) var stderr: String = ""
    /// The visible log. Capped at the most recent 80 chunks, as in the legacy reducer.
    public internal(set) var lines: [OperationLine] = []
    public internal(set) var error: BrewweryError?

    init(handle: OperationHandle) {
        self.id = handle.id
        self.kind = handle.kind
        self.command = handle.command
        self.target = handle.target
        self.timeoutSeconds = handle.timeoutSeconds
    }

    static let maximumLines = 80
    static let liveOutputLimit = 120_000
}

/// What a finished operation reports back to the caller.
public enum OperationOutcome: Sendable {
    case completed(stdout: String, stderr: String)
    case failed(BrewweryError, stdout: String, stderr: String)

    public var error: BrewweryError? {
        if case .failed(let error, _, _) = self { return error }
        return nil
    }
}

/// Serialises mutating Homebrew operations and owns the progress state the UI renders.
///
/// Homebrew itself refuses to run two mutating commands at once, and the legacy app enforced
/// one streaming operation per window. The same rule is enforced here: a second request
/// while one is running fails with `OPERATION_IN_PROGRESS` rather than queueing silently.
/// Reads are unaffected — they never go through the coordinator.
@MainActor
@Observable
public final class OperationCoordinator {
    public private(set) var progress: OperationProgress?
    /// `true` between the user confirming a cancellation and the process actually exiting.
    public private(set) var isCancelling = false

    private let client: HomebrewClient
    private var dismissTask: Task<Void, Never>?
    /// How long a successful operation's panel stays up before closing itself. Failed and
    /// cancelled operations stay until dismissed, because their output is what the user needs.
    private let successDismissDelay: Duration?

    public init(client: HomebrewClient, successDismissDelay: Duration? = .seconds(2)) {
        self.client = client
        self.successDismissDelay = successDismissDelay
    }

    public var isRunning: Bool { progress?.status == .running }

    /// Runs one streaming operation to completion, publishing live output as it arrives.
    ///
    /// - Throws: `OPERATION_IN_PROGRESS` when another mutating operation is already running,
    ///   or a validation/detection error before anything is spawned.
    public func run(
        _ command: HomebrewCommand,
        kind: OperationKind,
        target: String? = nil
    ) async throws(BrewweryError) -> OperationOutcome {
        guard !isRunning else { throw .operationInProgress }

        let id = UUID()
        let handle = OperationHandle(
            id: id,
            kind: kind,
            command: command.displayCommand(),
            target: target,
            timeoutSeconds: kind.timeoutSeconds
        )

        let events = try await client.stream(command, kind: kind, id: id)

        let state = OperationProgress(handle: handle)
        dismissTask?.cancel()
        progress = state
        isCancelling = false

        var outcome: OperationOutcome = .failed(
            BrewweryError(code: .unknownError, message: "The Homebrew operation produced no result."),
            stdout: "",
            stderr: ""
        )

        for await event in events {
            switch event {
            case .started:
                state.status = .running

            case .output(let stream, let chunk, let timestamp):
                apply(chunk: chunk, stream: stream, at: timestamp, to: state)

            case .completed(let stdout, let stderr, _, _):
                state.status = .success
                state.stdout = stdout
                state.stderr = stderr
                outcome = .completed(stdout: stdout, stderr: stderr)

            case .failed(let stdout, let stderr, _, let error, _):
                state.status = switch error.code {
                case .operationCancelled: .cancelled
                case .operationTimeout: .timedOut
                default: .failed
                }
                state.stdout = stdout
                state.stderr = stderr
                state.error = error
                outcome = .failed(error, stdout: stdout, stderr: stderr)
            }
        }

        isCancelling = false
        if case .completed = outcome { scheduleDismissal(of: state.id) }
        return outcome
    }

    private func scheduleDismissal(of id: UUID) {
        guard let successDismissDelay else { return }
        dismissTask = Task { [weak self] in
            try? await Task.sleep(for: successDismissDelay)
            guard !Task.isCancelled, let self, self.progress?.id == id, self.progress?.status == .success else { return }
            self.progress = nil
        }
    }

    /// Asks the runner to terminate the active operation's process group.
    public func cancel() async {
        guard let progress, progress.status == .running else { return }
        isCancelling = true
        let cancelled = await client.cancelOperation(progress.id)
        if !cancelled { isCancelling = false }
    }

    /// Dismisses a finished operation's panel.
    public func clear() {
        guard progress?.status != .running else { return }
        dismissTask?.cancel()
        progress = nil
        isCancelling = false
    }

    private func apply(chunk: String, stream: OutputStream, at timestamp: Date, to state: OperationProgress) {
        switch stream {
        case .stdout:
            state.stdout = BoundedOutput.appending(chunk, to: state.stdout, limit: OperationProgress.liveOutputLimit)
        case .stderr:
            state.stderr = BoundedOutput.appending(chunk, to: state.stderr, limit: OperationProgress.liveOutputLimit)
        }

        state.lines.append(
            OperationLine(stream: stream, text: BoundedOutput.compactChunk(chunk), timestamp: timestamp)
        )
        if state.lines.count > OperationProgress.maximumLines {
            state.lines.removeFirst(state.lines.count - OperationProgress.maximumLines)
        }
    }
}
