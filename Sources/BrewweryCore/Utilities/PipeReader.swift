import Darwin
import Foundation

/// Reads directly on a dispatch worker, with no intermediate unbounded stream of chunks.
enum PipeReader {
    struct Capture: Sendable {
        var data = Data()
        var exceededLimit = false
        var text: String { String(decoding: data, as: UTF8.self).trimmed }
    }

    static func drain(_ handle: FileHandle, receive: (Data) -> Void) {
        defer { try? handle.close() }
        var bytes = [UInt8](repeating: 0, count: 16_384)
        while true {
            let count = bytes.withUnsafeMutableBytes { Darwin.read(handle.fileDescriptor, $0.baseAddress, $0.count) }
            if count < 0, errno == EINTR { continue }
            guard count > 0 else { return }
            receive(Data(bytes.prefix(count)))
        }
    }

    static func capture(_ handle: FileHandle, limit: Int, overflow: () -> Void) -> Capture {
        var result = Capture()
        drain(handle) { data in
            let remaining = max(0, limit - result.data.count)
            result.data.append(data.prefix(remaining))
            if data.count > remaining, !result.exceededLimit {
                result.exceededLimit = true
                overflow()
            }
        }
        return result
    }

    static func captureAsync(_ handle: FileHandle, limit: Int, overflow: @escaping @Sendable () -> Void) async -> Capture {
        await withCheckedContinuation { continuation in
            DispatchQueue.global().async {
                continuation.resume(returning: capture(handle, limit: limit, overflow: overflow))
            }
        }
    }
}

/// Keep an incomplete UTF-8 sequence for the next read instead of replacing split glyphs.
struct PipeTextDecoder {
    private var pending = Data()

    mutating func append(_ data: Data) -> String {
        pending.append(data)
        var end = pending.count
        if let lead = pending.indices.reversed().first(where: { pending[$0] & 0xc0 != 0x80 }) {
            let byte = pending[lead]
            let length = byte < 0x80 ? 1 : byte & 0xe0 == 0xc0 ? 2 : byte & 0xf0 == 0xe0 ? 3 : byte & 0xf8 == 0xf0 ? 4 : 1
            if pending.count - lead < length { end = lead }
        }
        let text = String(decoding: pending.prefix(end), as: UTF8.self)
        pending = Data(pending.dropFirst(end))
        return text
    }

    mutating func finish() -> String {
        defer { pending = Data() }
        return String(decoding: pending, as: UTF8.self)
    }
}
