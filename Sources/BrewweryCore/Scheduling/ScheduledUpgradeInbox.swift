import Foundation

/// Hands scheduled-upgrade results from the background agent to the app.
///
/// The agent never writes `history.json`: the app keeps History in memory and saves the whole
/// list, so a second writer's entries would be overwritten by the app's next save. Instead
/// each run drops one file here and the app moves its entries into History. Every file has
/// exactly one writer and one reader, so the two processes never need to coordinate.
public struct ScheduledUpgradeInbox: Sendable {
    public let directory: URL

    public init(directory: URL? = nil) {
        self.directory = directory ?? brewweryApplicationSupportDirectory()
            .appendingPathComponent("Scheduled Upgrades", isDirectory: true)
    }

    /// Writes one run's entries atomically, so a concurrent `collect()` sees all or nothing.
    public func deliver(_ entries: [HistoryEntry], at date: Date = Date()) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        // Zero-padded milliseconds first, so name order is delivery order.
        let stamp = String(format: "%015.0f", (date.timeIntervalSince1970 * 1000).rounded(.down))
        let url = directory.appendingPathComponent("\(stamp)-\(UUID().uuidString).json")
        try encoder.encode(entries).write(to: url, options: .atomic)
    }

    /// Removes every delivered file and returns its entries, oldest delivery first.
    ///
    /// A file that cannot be decoded is renamed to `*.unreadable` rather than deleted, so the
    /// output stays available for diagnosis and is never offered twice. A file that cannot be
    /// removed is left for the next call instead of being imported twice.
    public func collect() -> [HistoryEntry] {
        let fileManager = FileManager.default
        guard let names = try? fileManager.contentsOfDirectory(atPath: directory.path) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        var collected: [HistoryEntry] = []
        for name in names.sorted() where name.hasSuffix(".json") && !name.hasPrefix(".") {
            let url = directory.appendingPathComponent(name)
            guard let data = try? Data(contentsOf: url) else { continue }
            guard let entries = try? decoder.decode([HistoryEntry].self, from: data) else {
                Log.persistence.error("Unreadable scheduled upgrade result \(name, privacy: .public)")
                try? fileManager.moveItem(at: url, to: url.appendingPathExtension("unreadable"))
                continue
            }
            guard (try? fileManager.removeItem(at: url)) != nil else { continue }
            collected += entries
        }
        return collected
    }
}
