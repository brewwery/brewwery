import Foundation

private enum JSONFileIO {
    static let queue = DispatchQueue(label: "com.brewwery.json-persistence", qos: .utility)
}

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

    func load() throws -> Value? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return try decode(Data(contentsOf: url))
    }

    private func decode(_ data: Data) throws -> Value {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(Value.self, from: data)
    }

    func save(_ value: Value) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            JSONFileIO.queue.async {
                do {
                    try write(value)
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func write(_ value: Value) throws {
        // Never overwrite corrupt data until an untouched recovery copy exists.
        if FileManager.default.fileExists(atPath: url.path) {
            let previous = try Data(contentsOf: url)
            if (try? decode(previous)) == nil {
                let backup = url.appendingPathExtension("unreadable-\(UUID().uuidString).bak")
                try FileManager.default.copyItem(at: url, to: backup)
            }
        }
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(value).write(to: url, options: .atomic)
    }

    func delete() {
        try? FileManager.default.removeItem(at: url)
    }
}
