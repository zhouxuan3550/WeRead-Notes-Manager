import XCTest
@testable import WeReadNotesManager

final class AppUpdateServiceTests: XCTestCase {
    func testIsVersionNewerThanComparesSemanticParts() {
        XCTAssertTrue(AppUpdateService.isVersion("1.0.14", newerThan: "1.0.13"))
        XCTAssertTrue(AppUpdateService.isVersion("v1.1.0", newerThan: "1.0.99"))
        XCTAssertFalse(AppUpdateService.isVersion("1.0.13", newerThan: "1.0.13"))
        XCTAssertFalse(AppUpdateService.isVersion("1.0.12", newerThan: "1.0.13"))
    }
}
