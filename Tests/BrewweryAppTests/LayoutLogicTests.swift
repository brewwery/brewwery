import XCTest
@testable import Brewwery

final class LayoutLogicTests: XCTestCase {

    // MARK: - Keyboard navigation

    func testArrowKeysStartAtTheFirstRowAndClamp() {
        XCTAssertEqual(TableNavigation.index(from: nil, moving: 1, count: 5), 0)
        XCTAssertEqual(TableNavigation.index(from: nil, moving: -1, count: 5), 0)
        XCTAssertEqual(TableNavigation.index(from: 0, moving: 1, count: 5), 1)
        XCTAssertEqual(TableNavigation.index(from: 4, moving: 1, count: 5), 4)
        XCTAssertEqual(TableNavigation.index(from: 0, moving: -1, count: 5), 0)
    }

    func testHomeAndEndJumpToTheEnds() {
        XCTAssertEqual(TableNavigation.index(jumpingTo: 0, count: 68), 0)
        XCTAssertEqual(TableNavigation.index(jumpingTo: 67, count: 68), 67)
        XCTAssertEqual(TableNavigation.index(jumpingTo: 500, count: 68), 67)
    }

    func testNavigationIsIgnoredOnAnEmptyTable() {
        XCTAssertNil(TableNavigation.index(from: nil, moving: 1, count: 0))
        XCTAssertNil(TableNavigation.index(jumpingTo: 0, count: 0))
    }

    // MARK: - Column tracks

    func testFixedTracksKeepTheirWidthAndFlexibleOnesShareByWeight() {
        let widths = TrackLayout.widths(
            for: [.flexible(minimum: 100, weight: 1), .fixed(120), .flexible(minimum: 100, weight: 3)],
            totalWidth: 720
        )

        XCTAssertEqual(widths[1], 120)
        // 720 - 120 - 200 = 400 left over, split 1:3.
        XCTAssertEqual(widths[0], 200, accuracy: 0.001)
        XCTAssertEqual(widths[2], 400, accuracy: 0.001)
        XCTAssertEqual(widths.reduce(0, +), 720, accuracy: 0.001)
    }

    /// A narrow window scales every column down instead of letting controls escape the table.
    func testTracksShrinkProportionallyWhenTheyCannotFit() {
        let widths = TrackLayout.widths(for: [.fixed(300), .flexible(minimum: 300, weight: 1)], totalWidth: 400)

        XCTAssertEqual(widths.reduce(0, +), 400, accuracy: 0.001)
        XCTAssertEqual(widths[0], widths[1], accuracy: 0.001)
    }

    /// The real Services table at the default window width must fit without shrinking.
    func testServicesColumnsFitTheDefaultWindow() {
        let contentWidth = Metrics.defaultWindowSize.width - Metrics.sidebarWidth - 1 - Metrics.contentPadding * 2
        let tracks: [TableColumnWidth] = [
            .flexible(minimum: 150, weight: 1.6), .fixed(128), .fixed(120),
            .flexible(minimum: 150, weight: 1.6), .fixed(252)
        ]

        let widths = TrackLayout.widths(for: tracks, totalWidth: contentWidth)

        XCTAssertEqual(widths[4], 252, "the Actions column was squeezed")
    }
}
