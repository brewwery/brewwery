import Darwin
import Foundation

/// One Homebrew mutation at a time across processes.
///
/// The runner already admits one mutation per process. The scheduled-upgrade agent is a
/// second process, so the app and the agent also share an advisory `flock(2)` on one file.
/// The kernel drops the lock when its descriptor closes, including when a process crashes, so
/// a stale lock cannot outlive its owner.
public struct MutationLock: Sendable {
    public let url: URL

    public init(url: URL) {
        self.url = url
    }

    /// `~/Library/Application Support/Brewwery/homebrew-mutation.lock`.
    public static var applicationSupport: MutationLock {
        MutationLock(url: brewweryApplicationSupportDirectory().appendingPathComponent("homebrew-mutation.lock"))
    }

    /// Takes the lock without waiting, or returns `nil` when another descriptor holds it.
    public func tryAcquire() -> Token? {
        try? FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        // O_CLOEXEC: `brew` and everything it spawns must not inherit the descriptor, or a
        // daemon started by Homebrew would hold the lock long after the operation ended.
        let descriptor = open(url.path, O_RDWR | O_CREAT | O_CLOEXEC, 0o600)
        guard descriptor >= 0 else {
            Log.process.error("Cannot open the mutation lock: errno \(errno, privacy: .public)")
            return nil
        }
        guard flock(descriptor, LOCK_EX | LOCK_NB) == 0 else {
            close(descriptor)
            return nil
        }
        return Token(descriptor: descriptor)
    }

    /// Holds the lock until `release()` or deinitialisation.
    public final class Token: @unchecked Sendable {
        // Mutated only by `release()`, which callers invoke from one owner.
        private var descriptor: Int32

        fileprivate init(descriptor: Int32) {
            self.descriptor = descriptor
        }

        public func release() {
            guard descriptor >= 0 else { return }
            flock(descriptor, LOCK_UN)
            close(descriptor)
            descriptor = -1
        }

        deinit { release() }
    }
}
