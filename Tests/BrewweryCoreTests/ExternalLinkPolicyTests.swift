import XCTest
@testable import BrewweryCore

final class ExternalLinkPolicyTests: XCTestCase {

    func testAllowsOnlyTheDocumentedTargets() {
        XCTAssertTrue(ExternalLinkPolicy.isAllowed("https://brew.sh"))
        XCTAssertTrue(ExternalLinkPolicy.isAllowed("https://docs.brew.sh/FAQ"))
        XCTAssertTrue(ExternalLinkPolicy.isAllowed("https://www.brewwery.com"))
        XCTAssertTrue(ExternalLinkPolicy.isAllowed("https://docs.brewwery.com/security"))
        XCTAssertTrue(ExternalLinkPolicy.isAllowed("https://github.com/brewwery/brewwery"))
        XCTAssertTrue(ExternalLinkPolicy.isAllowed("https://github.com/brewwery/brewwery/issues/new"))
    }

    func testRejectsOtherHostsSchemesAndPaths() {
        // Only the Brewwery repository on GitHub, not all of github.com.
        XCTAssertFalse(ExternalLinkPolicy.isAllowed("https://github.com/someone/else"))
        XCTAssertFalse(ExternalLinkPolicy.isAllowed("https://github.com/brewwery/brewwery-evil"))
        XCTAssertFalse(ExternalLinkPolicy.isAllowed("http://brew.sh"))
        XCTAssertFalse(ExternalLinkPolicy.isAllowed("https://evil.brew.sh"))
        XCTAssertFalse(ExternalLinkPolicy.isAllowed("file:///etc/passwd"))
        XCTAssertFalse(ExternalLinkPolicy.isAllowed("javascript:alert(1)"))
        XCTAssertFalse(ExternalLinkPolicy.isAllowed("not a url"))
    }

    func testHomepagesAcceptHTTPAndHTTPSOnly() {
        XCTAssertTrue(ExternalLinkPolicy.isSafeHomepage("https://redis.io/"))
        XCTAssertTrue(ExternalLinkPolicy.isSafeHomepage("http://example.org"))
        XCTAssertFalse(ExternalLinkPolicy.isSafeHomepage("file:///Applications"))
        XCTAssertFalse(ExternalLinkPolicy.isSafeHomepage("javascript:alert(1)"))
        XCTAssertFalse(ExternalLinkPolicy.isSafeHomepage("https://"))
    }
}
