import Foundation

/// `parser.rs::parse_key_value_lines` — splits each line on the first `:` and trims both
/// halves. Lines without a colon are dropped.
public enum KeyValueParser {
    public static func parse(_ output: String) -> [(key: String, value: String)] {
        output.split(separator: "\n", omittingEmptySubsequences: false).compactMap { line in
            guard let separator = line.firstIndex(of: ":") else { return nil }
            let key = line[line.startIndex..<separator].trimmed
            let value = line[line.index(after: separator)...].trimmed
            return (key, value)
        }
    }

    /// `config_value` — returns the value for a key, treating an empty value as missing.
    public static func value(for key: String, in pairs: [(key: String, value: String)]) -> String? {
        pairs.first { $0.key == key }.map(\.value).flatMap { $0.isEmpty ? nil : $0 }
    }
}

extension StringProtocol {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
