import Foundation

/// Ports `cleanup.rs` parsing.
public enum CleanupParser {

    /// `parse_cleanup_preview` — one item per `Would remove:` line.
    public static func parsePreview(_ rawOutput: String) -> CleanupPreview {
        let items = rawOutput
            .split(separator: "\n", omittingEmptySubsequences: false)
            .compactMap { parseItem(String($0)) }

        return CleanupPreview(
            items: items,
            totalSize: findTotal(rawOutput),
            rawOutput: rawOutput.isEmpty ? nil : rawOutput
        )
    }

    /// `parse_cleanup_item` — accepts both the plain and the broken-link prefix.
    static func parseItem(_ line: String) -> CleanupItem? {
        let remainder: String
        if let value = line.dropPrefixIfPresent("Would remove: ") {
            remainder = value
        } else if let value = line.dropPrefixIfPresent("Would remove (broken link): ") {
            remainder = value
        } else {
            return nil
        }

        let (path, size) = splitPathAndSize(remainder)
        let name = path.split(separator: "/").last.map(String.init)

        return CleanupItem(
            name: name,
            path: path,
            size: size,
            kind: classify(path)
        )
    }

    /// `split_path_size` — Homebrew appends `(12 files, 3.4MB)`; the size is the part after
    /// the last `, `, or the whole parenthetical when there is no file count.
    static func splitPathAndSize(_ value: String) -> (path: String, size: String?) {
        guard let range = value.range(of: " (", options: .backwards) else { return (value, nil) }
        let path = String(value[value.startIndex..<range.lowerBound])
        var detail = String(value[range.upperBound...])
        while detail.hasSuffix(")") { detail.removeLast() }
        let size = detail.range(of: ", ", options: .backwards)
            .map { String(detail[$0.upperBound...]) } ?? detail
        return (path, size)
    }

    /// `classify_cleanup_item`.
    static func classify(_ path: String) -> CleanupItemKind {
        if path.contains("/Caches/Homebrew/") { return .cache }
        if path.contains("/Cellar/") { return .oldVersion }
        if path.contains("/Logs/Homebrew/") { return .download }
        return .unknown
    }

    /// `find_cleanup_total` — reads the "free approximately N of disk space." trailer.
    public static func findTotal(_ output: String) -> String? {
        let marker = "free approximately "
        for line in output.split(separator: "\n", omittingEmptySubsequences: false) {
            guard let range = line.range(of: marker) else { continue }
            var value = String(line[range.upperBound...])
            while value.hasSuffix(".") { value.removeLast() }
            if value.hasSuffix(" of disk space") { value.removeLast(" of disk space".count) }
            return value.trimmed
        }
        return nil
    }

    /// `countCleanupItems()` from the streaming path: lines Homebrew logs while removing.
    public static func countRemovals(_ output: String) -> Int {
        output
            .split(separator: "\n", omittingEmptySubsequences: false)
            .count { $0.hasPrefix("Removing:") || $0.hasPrefix("Pruned ") }
    }

    /// `findCleanupTotal()` from the streaming path, which reads the completed run's
    /// "freed …" trailer rather than the preview's "free approximately …".
    public static func findFreedSpace(_ output: String) -> String? {
        let marker = "freed "
        guard let line = output
            .split(separator: "\n", omittingEmptySubsequences: false)
            .first(where: { $0.lowercased().contains(marker) })
        else { return nil }

        let lowercased = line.lowercased()
        guard let range = lowercased.range(of: marker, options: .backwards) else { return nil }
        let offset = lowercased.distance(from: lowercased.startIndex, to: range.upperBound)
        var value = String(line.dropFirst(offset))

        if let approximately = value.range(of: "approximately ", options: [.caseInsensitive, .anchored]) {
            value = String(value[approximately.upperBound...])
        }
        value = value.trimmed
        if value.hasSuffix(".") { value.removeLast() }
        if value.lowercased().hasSuffix(" of disk space") { value.removeLast(" of disk space".count) }
        value = value.trimmed
        if value.hasSuffix(".") { value.removeLast() }
        return value.trimmed.nilIfEmpty
    }
}

extension StringProtocol {
    func dropPrefixIfPresent(_ prefix: String) -> String? {
        hasPrefix(prefix) ? String(dropFirst(prefix.count)) : nil
    }
}
