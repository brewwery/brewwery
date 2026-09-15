import Darwin
import Foundation

/// A directly spawned child process with its own process group.
///
/// Foundation's `Process` places the child in Brewwery's own process group, which means a
/// terminate signal reaches `brew` but not the `git`, `curl` or `ruby` processes it forks.
/// The legacy Electron implementation had exactly that gap. Spawning through `posix_spawn`
/// with `POSIX_SPAWN_SETPGROUP` makes the child a group leader, so `kill(-pid, …)` reaches
/// the whole tree and cancellation cannot leave orphans behind.
///
/// No shell is involved: the executable path and the argument vector are passed directly.
final class ChildProcess: @unchecked Sendable {
    let pid: pid_t
    let standardOutput: FileHandle
    let standardError: FileHandle

    private let lock = NSLock()
    private var terminationStatus: Int32?
    private var waiters: [CheckedContinuation<Int32, Never>] = []
    private var blockingWaiters: [DispatchSemaphore] = []
    private var exitSource: DispatchSourceProcess?

    private init(pid: pid_t, standardOutput: FileHandle, standardError: FileHandle) {
        self.pid = pid
        self.standardOutput = standardOutput
        self.standardError = standardError
        installExitWatcher()
    }

    // MARK: - Spawning

    static func spawn(
        executablePath: String,
        arguments: [String],
        environment: [String: String]
    ) throws(BrewweryError) -> ChildProcess {
        var outputPipe: [Int32] = [0, 0]
        var errorPipe: [Int32] = [0, 0]
        guard pipe(&outputPipe) == 0 else { throw .init(code: .unknownError, message: "unable to create output pipe") }
        guard pipe(&errorPipe) == 0 else {
            close(outputPipe[0]); close(outputPipe[1])
            throw .init(code: .unknownError, message: "unable to create error pipe")
        }

        var fileActions: posix_spawn_file_actions_t?
        posix_spawn_file_actions_init(&fileActions)
        defer { posix_spawn_file_actions_destroy(&fileActions) }
        // The child writes to the pipe write-ends as stdout/stderr and closes the read-ends.
        posix_spawn_file_actions_adddup2(&fileActions, outputPipe[1], STDOUT_FILENO)
        posix_spawn_file_actions_adddup2(&fileActions, errorPipe[1], STDERR_FILENO)
        posix_spawn_file_actions_addclose(&fileActions, outputPipe[0])
        posix_spawn_file_actions_addclose(&fileActions, errorPipe[0])
        posix_spawn_file_actions_addclose(&fileActions, outputPipe[1])
        posix_spawn_file_actions_addclose(&fileActions, errorPipe[1])

        var attributes: posix_spawnattr_t?
        posix_spawnattr_init(&attributes)
        defer { posix_spawnattr_destroy(&attributes) }
        // pgroup 0 => the child becomes the leader of a new group whose id is its own pid.
        posix_spawnattr_setpgroup(&attributes, 0)
        posix_spawnattr_setflags(&attributes, Int16(POSIX_SPAWN_SETPGROUP))

        let argv: [UnsafeMutablePointer<CChar>?] =
            ([executablePath] + arguments).map { strdup($0) } + [nil]
        let envp: [UnsafeMutablePointer<CChar>?] =
            environment.map { strdup("\($0.key)=\($0.value)") } + [nil]
        defer {
            argv.forEach { free($0) }
            envp.forEach { free($0) }
        }

        var childPID: pid_t = 0
        let result = posix_spawn(&childPID, executablePath, &fileActions, &attributes, argv, envp)

        // The parent never writes to these pipes.
        close(outputPipe[1])
        close(errorPipe[1])

        guard result == 0 else {
            close(outputPipe[0])
            close(errorPipe[0])
            let reason = String(cString: strerror(result))
            Log.process.error("posix_spawn failed: \(reason, privacy: .public)")
            guard result != EACCES, result != EPERM else {
                throw BrewweryError(
                    code: .permissionDenied,
                    message: "Brewwery does not have permission to run this Homebrew command.",
                    raw: reason
                )
            }
            throw BrewweryError(code: .brewCommandFailed, message: reason, raw: reason)
        }

        return ChildProcess(
            pid: childPID,
            standardOutput: FileHandle(fileDescriptor: outputPipe[0], closeOnDealloc: true),
            standardError: FileHandle(fileDescriptor: errorPipe[0], closeOnDealloc: true)
        )
    }

    // MARK: - Lifecycle

    private func installExitWatcher() {
        let source = DispatchSource.makeProcessSource(identifier: pid, eventMask: .exit, queue: .global())
        source.setEventHandler { [weak self] in
            guard let self else { return }
            var status: Int32 = 0
            // Reap the child so it never becomes a zombie.
            let reaped = waitpid(self.pid, &status, 0)
            self.finish(status: reaped == self.pid ? Self.exitCode(from: status) : -1)
            self.exitSource?.cancel()
        }
        exitSource = source
        source.resume()
    }

    private static func exitCode(from rawStatus: Int32) -> Int32 {
        // WIFEXITED / WEXITSTATUS / WTERMSIG are macros, so decode the wait status directly.
        if rawStatus & 0x7F == 0 { return (rawStatus >> 8) & 0xFF }
        return 128 + (rawStatus & 0x7F)
    }

    private func finish(status: Int32) {
        lock.lock()
        guard terminationStatus == nil else { return lock.unlock() }
        terminationStatus = status
        let pending = waiters
        let blocking = blockingWaiters
        waiters = []
        blockingWaiters = []
        lock.unlock()
        pending.forEach { $0.resume(returning: status) }
        blocking.forEach { $0.signal() }
    }

    var hasTerminated: Bool {
        lock.lock()
        defer { lock.unlock() }
        return terminationStatus != nil
    }

    /// Awaits the child's exit code. Safe to call from multiple tasks.
    func waitForExit() async -> Int32 {
        await withCheckedContinuation { continuation in
            lock.lock()
            if let terminationStatus {
                lock.unlock()
                continuation.resume(returning: terminationStatus)
            } else {
                waiters.append(continuation)
                lock.unlock()
            }
        }
    }

    /// Blocking wait, for the short synchronous probes that run before any actor exists.
    ///
    /// Callers must never `waitpid` themselves: the exit watcher already reaps the child, and
    /// a second reap returns `ECHILD` with an untouched status word — which silently turns a
    /// failed `brew --version` into a successful one.
    func waitForExitBlocking() -> Int32 {
        lock.lock()
        if let terminationStatus {
            lock.unlock()
            return terminationStatus
        }
        let semaphore = DispatchSemaphore(value: 0)
        blockingWaiters.append(semaphore)
        lock.unlock()

        semaphore.wait()

        lock.lock()
        defer { lock.unlock() }
        return terminationStatus ?? -1
    }

    /// Signals the child's entire process group, falling back to the child alone if the
    /// group is already gone.
    @discardableResult
    func signalGroup(_ signal: Int32) -> Bool {
        guard !hasTerminated else { return false }
        if kill(-pid, signal) == 0 { return true }
        return kill(pid, signal) == 0
    }
}
