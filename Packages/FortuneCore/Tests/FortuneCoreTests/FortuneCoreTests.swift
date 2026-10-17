import XCTest
@testable import FortuneCore

final class FortuneCoreTests: XCTestCase {
    func testVersionIsSet() {
        XCTAssertFalse(FortuneCore.version.isEmpty)
    }
}
