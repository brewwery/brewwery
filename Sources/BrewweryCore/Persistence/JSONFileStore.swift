import Foundation

/// `~/Library/Application Support/Brewwery/`, the native equivalent of the Electron
/// `userData` directory the legacy app used for its settings file.
func brewweryApplicationSupportDirectory() -> URL {
    let base = FileManager.default
        .urls(for: .applicationSupportDirectory, in: .userDomainMask)
        .first ?? FileManager.default.homeDirectoryForCurrentUser
    return base.appendingPathComponent("Brewwery", isDirectory: true)
}

/// Small atomic JSON file store used for data that outgrows `UserDefaults` — today the
/// operation history and the favourites list.
struct JSONFileStore<Value: Codable & Sendable>: Sendable {
    let url: URL

    init(fileName: String, directory: URL = brewweryApplicationSupportDirectory()) {
        self.url = directory.appendingPathComponent(fileName)
    }

    func load() -> Value? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(Value.self, from: data)
        } catch {
            Log.persistence.error("Discarding unreadable \(url.lastPathComponent, privacy: .public)")
            return nil
        }
    }

    func save(_ value: Value) {
        do {
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(value).write(to: url, options: .atomic)
        } catch {
            Log.persistence.error("Failed to write \(url.lastPathComponent, privacy: .public)")
        }
    }

    func delete() {
        try? FileManager.default.removeItem(at: url)
    }
}
