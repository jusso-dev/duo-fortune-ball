import XCTest
import FortuneCore
@testable import FoldFortune

@MainActor
final class FoldFortuneTests: XCTestCase {
    func testModelRevealsWhenMockOpens() async {
        let mock = MockFoldStateService(initial: .closed)
        let model = FortuneModel(foldService: mock, answers: StarterAnswers.all)
        XCTAssertEqual(model.mode, .fold)
        model.send(.questionChanged("Will it be sunny?"))
        for posture in MockFoldStateService.openingScript { model.send(.postureChanged(posture)) }
        XCTAssertNotNil(model.phase.answer)
    }

    func testModelUsesTapWithoutHinge() {
        let model = FortuneModel(foldService: UnavailableFoldStateService(), answers: StarterAnswers.all)
        XCTAssertEqual(model.mode, .tap)
        model.send(.questionChanged("Tea or coffee?"))
        model.send(.tapReveal)
        XCTAssertNotNil(model.phase.answer)
    }

    func testHingeMappingWithoutHingeIsUnavailable() {
        XCTAssertEqual(HingeFoldStateService.posture(for: nil), .unavailable)
    }
}
