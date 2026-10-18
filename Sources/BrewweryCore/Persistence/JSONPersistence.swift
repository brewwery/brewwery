import Foundation
import Observation

/// Keeps at most one write in flight and one newer snapshot. Encoding, recovery copies and
/// atomic replacement happen on JSONFileStore's serial utility queue, never on the UI thread.
@MainActor
@Observable
final class JSONPersistence<Value: Codable & Sendable> {
    private(set) var error: String?
    private(set) var hasUnsavedChanges = false
    private(set) var isSaving = false

    private let store: JSONFileStore<Value>
    @ObservationIgnored private let write: @Sendable (Value) async throws -> Void
    @ObservationIgnored private var pending: Value?
    @ObservationIgnored private var saveTask: Task<Void, Never>?

    init(store: JSONFileStore<Value>, write: (@Sendable (Value) async throws -> Void)? = nil) {
        self.store = store
        self.write = write ?? { try await store.save($0) }
    }

    func load() -> Value? {
        do {
            let value = try store.load()
            error = nil
            return value
        } catch {
            self.error = error.localizedDescription
            return nil
        }
    }

    func save(_ value: Value) {
        pending = value
        hasUnsavedChanges = true
        guard saveTask == nil else { return }
        isSaving = true
        saveTask = Task { await drain() }
    }

    /// A cancelled waiter must not cancel a disk write. Used by quit and test teardown.
    func flush() async -> Bool {
        while let task = saveTask { await task.value }
        return !hasUnsavedChanges
    }

    private func drain() async {
        defer { saveTask = nil; isSaving = false }
        while let value = pending {
            pending = nil
            do {
                try await write(value)
                if pending == nil {
                    hasUnsavedChanges = false
                    error = nil
                }
            } catch {
                // An older failed snapshot must not replace a newer pending one. A failed
                // latest write remains dirty in the owning store until explicit retry.
                if pending == nil { self.error = error.localizedDescription }
            }
        }
    }
}
