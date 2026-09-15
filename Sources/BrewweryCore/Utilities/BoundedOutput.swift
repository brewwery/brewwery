import Foundation

/// Keeps captured command output from growing without bound during long installs.
///
/// Ported from `appendBoundedOutput()`, which the legacy app ran in both the Electron main
/// process (200 000 chars) and the renderer (120 000 chars). When the cap is exceeded the
/// head and tail are kept and the middle is replaced by a marker, so the first phase and the
/// final failure of a long `brew install` both remain visible.
public struct BoundedOutput: Sendable {
    public static let marker = "\n\n[Brewwery trimmed earlier live output.]\n\n"

    private let limit: Int
    private var value: String = ""

    public init(limit: Int) {
        self.limit = limit
    }

    public var text: String { value }

    public mutating func append(_ chunk: String) {
        value = Self.appending(chunk, to: value, limit: limit)
    }

    public static func appending(_ chunk: String, to current: String, limit: Int) -> String {
        let combined = current + chunk
        guard combined.count > limit else { return combined }

        let headLength = Int(Double(limit) * 0.35)
        let tailLength = limit - headLength - marker.count
        guard tailLength > 0 else { return String(combined.suffix(limit)) }

        return String(combined.prefix(headLength)) + marker + String(combined.suffix(tailLength))
    }

    /// Cap applied to output captured for one streaming operation.
    public static let operationLimit = 200_000
    /// Cap applied to a single live chunk before it is appended to the visible log.
    public static let chunkLimit = 4_000
    /// Cap applied to each stored history field.
    public static let historyLimit = 20_000

    /// `compactChunk()` — a single oversized chunk is truncated with a count, not split.
    public static func compactChunk(_ chunk: String) -> String {
        guard chunk.count > chunkLimit else { return chunk }
        return String(chunk.prefix(chunkLimit))
            + "\n[Brewwery trimmed \(chunk.count - chunkLimit) characters from this live output chunk.]"
    }

    /// `compactOutput()` from the history store: keep 65 % head and 25 % tail.
    public static func compactHistory(_ value: String?) -> String? {
        guard let value, value.count > historyLimit else { return value }
        let headLength = Int(Double(historyLimit) * 0.65)
        let tailLength = Int(Double(historyLimit) * 0.25)
        let head = String(value.prefix(headLength))
        let tail = String(value.suffix(tailLength))
        let trimmedCount = value.count - headLength - tailLength
        return "\(head)\n\n[Brewwery trimmed \(trimmedCount) characters to keep History fast.]\n\n\(tail)"
    }
}
