import Foundation

/// Homebrew returns several fields as either a single string or an array of strings
/// (cask `name`, cask `installed`). Both shapes decode to an array.
enum StringOrArray: Decodable {
    case one(String)
    case many([String])

    var values: [String] {
        switch self {
        case .one(let value): [value]
        case .many(let values): values
        }
    }

    var first: String? { values.first }

    init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let value = try? container.decode(String.self) {
            self = .one(value)
        } else {
            self = .many(try container.decode([String].self))
        }
    }
}

enum HomebrewJSON {
    static let decoder = JSONDecoder()

    /// Decodes Homebrew JSON, converting any failure into the stable
    /// `BREW_JSON_PARSE_FAILED` code the UI keys its error copy off.
    static func decode<T: Decodable>(_ type: T.Type, from json: String) throws(BrewweryError) -> T {
        do {
            return try decoder.decode(type, from: Data(json.utf8))
        } catch {
            throw BrewweryError.parseFailed(String(describing: error))
        }
    }
}
