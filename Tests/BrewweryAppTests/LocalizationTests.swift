import XCTest

/// Every language the bundle declares must be complete: `CFBundleLocalizations` makes macOS
/// show the menus and system dialogs in that language, so a missing key would put English
/// text beside it. A translation must also carry the key's placeholders, or formatting the
/// string reads the wrong argument.
final class LocalizationTests: XCTestCase {
    private var repositoryRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // BrewweryAppTests
            .deletingLastPathComponent()  // Tests
            .deletingLastPathComponent()  // repository root
    }

    private func shippedLanguages() throws -> [String] {
        let contents = try Data(contentsOf: repositoryRoot.appendingPathComponent("Packaging/Info.plist"))
        let info = try XCTUnwrap(
            try PropertyListSerialization.propertyList(from: contents, format: nil) as? [String: Any]
        )
        return try XCTUnwrap(info["CFBundleLocalizations"] as? [String]).filter { $0 != "en" }
    }

    /// The catalog's keys that the code still uses, with their localizations.
    private func catalog() throws -> [String: [String: Any]] {
        let contents = try Data(contentsOf: repositoryRoot.appendingPathComponent("Localization/Localizable.xcstrings"))
        let root = try XCTUnwrap(try JSONSerialization.jsonObject(with: contents) as? [String: Any])
        let strings = try XCTUnwrap(root["strings"] as? [String: [String: Any]])
        return strings.filter { $0.value["extractionState"] as? String != "stale" }
    }

    func testShippedLanguagesAreComplete() throws {
        let languages = try shippedLanguages()
        XCTAssertFalse(languages.isEmpty)
        let strings = try catalog()

        for language in languages {
            let missing = strings.keys.filter { key in
                let localizations = strings[key]?["localizations"] as? [String: Any]
                return localizations?[language] == nil
            }
            XCTAssertEqual(missing.sorted(), [], "\(language): untranslated keys")
        }
    }

    func testTranslationsKeepTheirPlaceholders() throws {
        let languages = try shippedLanguages()
        let strings = try catalog()

        for (key, entry) in strings {
            let expected = Self.placeholders(in: key)
            let localizations = entry["localizations"] as? [String: Any] ?? [:]
            for language in languages {
                guard let localization = localizations[language] as? [String: Any] else { continue }
                for (form, value) in Self.values(of: localization) {
                    let actual = Self.placeholders(in: value)
                    // A plural form may leave the number out ("one" → "a cask"), never add one.
                    if form == "other" || form == "value" {
                        XCTAssertEqual(actual, expected, "\(language) \(form): \(key)")
                    } else {
                        XCTAssertTrue(actual.isSubset(of: expected), "\(language) \(form): \(key)")
                    }
                }
            }
        }
    }

    /// `(form, text)` pairs: `value` for a plain string, the plural category otherwise.
    private static func values(of localization: [String: Any]) -> [(String, String)] {
        if let unit = localization["stringUnit"] as? [String: Any], let value = unit["value"] as? String {
            return [("value", value)]
        }
        let plural = (localization["variations"] as? [String: Any])?["plural"] as? [String: Any] ?? [:]
        return plural.compactMap { form, variation in
            let unit = (variation as? [String: Any])?["stringUnit"] as? [String: Any]
            return (unit?["value"] as? String).map { (form, $0) }
        }
    }

    /// Argument positions and kinds: `%@` and `%2$@` are strings, `%lld` and friends integers.
    private static func placeholders(in text: String) -> Set<String> {
        let regex = try! NSRegularExpression(pattern: #"%(?:(\d+)\$)?(@|lld|ld|d)"#)
        var sequential = 0
        var found = Set<String>()
        for match in regex.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
            let position: Int
            if let range = Range(match.range(at: 1), in: text) {
                position = Int(text[range])! - 1
            } else {
                position = sequential
                sequential += 1
            }
            let kind = Range(match.range(at: 2), in: text).map { text[$0] == "@" ? "@" : "d" } ?? "?"
            found.insert("\(position)\(kind)")
        }
        return found
    }
}
