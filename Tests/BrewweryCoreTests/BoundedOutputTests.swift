import XCTest
@testable import BrewweryCore

final class BoundedOutputTests: XCTestCase {

    func testKeepsShortOutputIntact() {
        var output = BoundedOutput(limit: 100)
        output.append("hello ")
        output.append("world")

        XCTAssertEqual(output.text, "hello world")
    }

    func testTrimsTheMiddleAndKeepsBothEnds() {
        var output = BoundedOutput(limit: 200)
        output.append(String(repeating: "a", count: 150))
        output.append(String(repeating: "z", count: 150))

        let text = output.text
        XCTAssertLessThanOrEqual(text.count, 200)
        XCTAssertTrue(text.hasPrefix("a"))
        XCTAssertTrue(text.hasSuffix("z"))
        XCTAssertTrue(text.contains("[Brewwery trimmed earlier live output.]"))
    }

    func testCompactsAnOversizedSingleChunk() {
        let chunk = String(repeating: "x", count: BoundedOutput.chunkLimit + 500)

        let compacted = BoundedOutput.compactChunk(chunk)

        XCTAssertTrue(compacted.hasSuffix("[Brewwery trimmed 500 characters from this live output chunk.]"))
        XCTAssertEqual(BoundedOutput.compactChunk("short"), "short")
    }

    func testCompactsHistoryFields() {
        XCTAssertNil(BoundedOutput.compactHistory(nil))
        XCTAssertEqual(BoundedOutput.compactHistory("brief"), "brief")

        let long = String(repeating: "y", count: BoundedOutput.historyLimit + 1_000)
        let compacted = BoundedOutput.compactHistory(long)

        XCTAssertNotNil(compacted)
        XCTAssertTrue(compacted!.contains("to keep History fast."))
        XCTAssertLessThan(compacted!.count, long.count)
    }
}
