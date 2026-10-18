import Foundation
import Observation

/// Local operation log.
///
/// Matches the legacy `brewwery-operation-history` store: newest first, capped at 100
/// entries, with each output field trimmed before it is written. Nothing is uploaded,
/// synced, or used for telemetry — the file never leaves the Mac.
@MainActor
@Observable
public final class HistoryStore {
    public private(set) var entries: [HistoryEntry] = []
    public var persistenceError: String? { persistence.error }
    public var hasUnsavedChanges: Bool { persistence.hasUnsavedChanges }
    public var isSaving: Bool { persistence.isSaving }

    static let maximumEntries = 100
    private let persistence: JSONPersistence<[HistoryEntry]>

    public init(fileName: String = "history.json", directory: URL? = nil) {
        self.persistence = JSONPersistence(store: JSONFileStore(fileName: fileName, directory: directory ?? brewweryApplicationSupportDirectory()))
        reload()
    }

    /// Records an operation and returns the stored entry so callers can surface a toast.
    @discardableResult
    public func add(_ entry: HistoryEntry) -> HistoryEntry {
        let compacted = compact(entry)
        entries.insert(compacted, at: 0)
        if entries.count > Self.maximumEntries {
            entries.removeLast(entries.count - Self.maximumEntries)
        }
        persist()
        return compacted
    }

    public func clear() {
        entries = []
        persist()
    }

    public func retryPersistence() {
        if hasUnsavedChanges { persist() } else { reload() }
    }

    private func reload() {
        let loaded = persistence.load()
        if persistence.error == nil { entries = Array((loaded ?? []).prefix(Self.maximumEntries)).map(compact) }
    }

    private func persist() {
        persistence.save(entries)
    }

    public func flushPersistence() async -> Bool { await persistence.flush() }

    /// JSON payload for the "Export JSON" action, shaped like the legacy export.
    public func exportData() throws -> Data {
        struct Export: Encodable {
            let exportedAt: Date
            let entries: [HistoryEntry]
        }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(Export(exportedAt: Date(), entries: entries))
    }

    public static func exportFileName(date: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return "brewwery-history-\(formatter.string(from: date)).json"
    }

    private func compact(_ entry: HistoryEntry) -> HistoryEntry {
        var compacted = entry
        compacted.stdout = BoundedOutput.compactHistory(entry.stdout)
        compacted.stderr = BoundedOutput.compactHistory(entry.stderr)
        compacted.details = BoundedOutput.compactHistory(entry.details)
        if let error = entry.error {
            compacted.error = BrewweryError(
                code: error.code,
                message: error.message,
                raw: BoundedOutput.compactHistory(error.raw)
            )
        }
        return compacted
    }
}
