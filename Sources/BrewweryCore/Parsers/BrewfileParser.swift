import Foundation

/// Ports `brewfile.rs` parsing.
public enum BrewfileParser {
    public static func parse(_ content: String) -> [BrewfileEntry] {
        content
            .split(separator: "\n", omittingEmptySubsequences: false)
            .compactMap { parseEntry(String($0)) }
    }

    /// `parse_brewfile_entry` — blank lines and comments are skipped; the leading word
    /// selects the kind and the first quoted token is the name.
    static func parseEntry(_ line: String) -> BrewfileEntry? {
        let trimmed = line.trimmed
        guard !trimmed.isEmpty, !trimmed.hasPrefix("#") else { return nil }

        let keyword = trimmed.split(whereSeparator: \.isWhitespace).first.map(String.init) ?? "unknown"
        let kind = BrewfileEntryKind(rawValue: keyword) ?? .unknown

        return BrewfileEntry(
            kind: kind,
            name: quotedName(in: trimmed) ?? trimmed,
            raw: trimmed
        )
    }

    /// `extract_quoted_name` — the text between the first pair of double quotes.
    static func quotedName(in line: String) -> String? {
        guard let start = line.firstIndex(of: "\"") else { return nil }
        let rest = line[line.index(after: start)...]
        guard let end = rest.firstIndex(of: "\"") else { return nil }
        return String(rest[rest.startIndex..<end])
    }
}
