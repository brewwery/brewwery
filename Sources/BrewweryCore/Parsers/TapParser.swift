import Foundation

/// Ports `taps.rs::parse_taps`.
public enum TapParser {
    public static func parse(_ output: String) -> [BrewTap] {
        output
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map(\.trimmed)
            .filter { !$0.isEmpty }
            .map { BrewTap(name: $0, official: $0.hasPrefix("homebrew/")) }
    }
}
