import XCTest
import FortuneCore
@testable import FoldFortune

@MainActor
final class FoldFortuneTests: XCTestCase {
    func testModelRevealsWhenMockOpens() {
        let mock = MockFoldStateService(initial: .closed)
        let model = FortuneModel(foldService: mock, store: InMemoryAnswerSetStore())
        XCTAssertEqual(model.mode, .fold)
        model.send(.questionChanged("Will it be sunny?"))
        for posture in MockFoldStateService.openingScript { model.send(.postureChanged(posture)) }
        XCTAssertNotNil(model.phase.answer)
    }

    /// Drives the real path: the mock publishes postures and
    /// `observeFold` feeds them to the machine.
    func testObserveFoldRevealsWhenMockOpens() async throws {
        let mock = MockFoldStateService(initial: .closed)
        let model = FortuneModel(foldService: mock, store: InMemoryAnswerSetStore())
        model.send(.questionChanged("Will it be sunny?"))
        let observer = Task { await model.observeFold() }
        defer { observer.cancel() }

        for _ in 0..<200 where mock.subscriberCount == 0 {
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTAssertEqual(mock.subscriberCount, 1, "observeFold never subscribed")

        mock.play(MockFoldStateService.openingScript)
        for _ in 0..<200 where model.phase.answer == nil {
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTAssertNotNil(model.phase.answer)
        XCTAssertEqual(model.revealAnnouncement, model.phase.answer.map { "Answer: \($0.text)" })
    }

    func testNoAnnouncementBeforeReveal() {
        let model = FortuneModel(foldService: MockFoldStateService(initial: .closed), store: InMemoryAnswerSetStore())
        model.send(.questionChanged("Soon?"))
        XCTAssertNil(model.revealAnnouncement)
    }

    func testModelUsesTapWithoutHinge() {
        let model = FortuneModel(foldService: UnavailableFoldStateService(), store: InMemoryAnswerSetStore())
        XCTAssertEqual(model.mode, .tap)
        model.send(.questionChanged("Tea or coffee?"))
        model.send(.tapReveal)
        XCTAssertNotNil(model.phase.answer)
    }

    func testEditingAnswersPersistsAndFeedsMachine() throws {
        let store = InMemoryAnswerSetStore()
        let model = FortuneModel(foldService: UnavailableFoldStateService(), store: store)
        model.editAnswers { set in
            set = AnswerSet(name: "Mine", answers: [])
            try set.add("Custom only", tone: .yes)
        }
        XCTAssertEqual(try store.load()?.answers.map(\.text), ["Custom only"])
        model.send(.questionChanged("Q?"))
        model.send(.tapReveal)
        XCTAssertEqual(model.phase.answer?.text, "Custom only")
    }

    func testInvalidEditSurfacesError() {
        let model = FortuneModel(foldService: UnavailableFoldStateService(), store: InMemoryAnswerSetStore())
        model.editAnswers { try $0.add("   ", tone: .yes) }
        XCTAssertEqual(model.lastError, .emptyText)
    }

    func testHingeMappingWithoutHingeIsUnavailable() {
        XCTAssertEqual(HingeFoldStateService.posture(for: nil), .unavailable)
    }
}
