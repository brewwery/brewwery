import Foundation
import XCTest
@testable import Brewwery

/// VoiceOver audit.
///
/// SwiftUI only publishes its accessibility tree to an assistive client, and reading it from
/// outside needs the Accessibility privacy permission — which a test run should not require.
/// So the guarantee is structural instead: every icon-only control is an `IconButton`, whose
/// accessible name is a required argument, and this suite fails if a new icon-only `Button`
/// is written by hand anywhere in the app.
final class AccessibilityLintTests: XCTestCase {
    private static let sourcesDirectory = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("Sources/Brewwery")

    private func appSources() throws -> [(name: String, text: String)] {
        let enumerator = try XCTUnwrap(FileManager.default.enumerator(at: Self.sourcesDirectory, includingPropertiesForKeys: nil))
        return enumerator.compactMap { $0 as? URL }
            .filter { $0.pathExtension == "swift" }
            .compactMap { url in (try? String(contentsOf: url, encoding: .utf8)).map { (url.lastPathComponent, $0) } }
    }

    func testThereAreSourcesToAudit() throws {
        XCTAssertGreaterThan(try appSources().count, 30)
    }

    /// A `Button` whose label is nothing but an `Image` has no accessible name unless one is
    /// attached by hand, which is easy to forget. Those must be `IconButton`s.
    func testNoHandWrittenIconOnlyButtons() throws {
        let iconOnlyLabel = try NSRegularExpression(pattern: #"label:\s*\{\s*\n\s*Image\(systemName:[^\n]*\)[^\n]*\n\s*(\.[a-zA-Z]+\([^\n]*\)\s*\n\s*)*\}"#)
        let iconOnlyTrailing = try NSRegularExpression(pattern: #"Button\([^)]*\)\s*\{\s*\n\s*Image\(systemName:[^\n]*\n(\s*\.[a-zA-Z]+\([^\n]*\)\s*\n)*\s*\}"#)

        var offenders: [String] = []
        for (name, text) in try appSources() where name != "Components.swift" {
            let range = NSRange(text.startIndex..., in: text)
            for regex in [iconOnlyLabel, iconOnlyTrailing] {
                for match in regex.matches(in: text, range: range) {
                    guard let swiftRange = Range(match.range, in: text) else { continue }
                    let line = text[..<swiftRange.lowerBound].components(separatedBy: "\n").count
                    let following = text[swiftRange.upperBound...].prefix(200)
                    // A label attached immediately after is acceptable.
                    if following.contains(".accessibilityLabel(") { continue }
                    offenders.append("\(name):\(line)")
                }
            }
        }

        XCTAssertTrue(offenders.isEmpty, "icon-only buttons without an accessible name: \(offenders)")
    }

    func testIconButtonsAreUsedForTheKnownIconControls() throws {
        let joined = try appSources().map(\.text).joined()
        for label in ["\"Settings\", systemImage: \"gearshape\"", "systemImage: \"ellipsis\"", "systemImage: \"trash\""] {
            XCTAssertTrue(joined.contains(label), "expected an IconButton for \(label)")
        }
    }
}
