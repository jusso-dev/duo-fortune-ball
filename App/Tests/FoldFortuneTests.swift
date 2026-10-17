import XCTest
import UIKit
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

    func testPromptMatchesPosture() {
        let closed = FortuneModel(foldService: MockFoldStateService(initial: .closed), store: InMemoryAnswerSetStore())
        XCTAssertEqual(closed.promptText, "Open your phone to reveal the answer.")
        let open = FortuneModel(foldService: MockFoldStateService(initial: .open), store: InMemoryAnswerSetStore())
        XCTAssertEqual(open.promptText, "Close and reopen, or tap Reveal.")
        let flat = FortuneModel(foldService: UnavailableFoldStateService(), store: InMemoryAnswerSetStore())
        XCTAssertEqual(flat.promptText, "Tap Reveal when you're ready.")
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

    func testMockedLaunchStates() {
        let question = "Will the bus be on time?"
        let closed = FortuneModel.mocked(.closed, question: question)
        XCTAssertEqual(closed.phase, .asking(question: question))
        XCTAssertEqual(closed.mode, .fold)
        XCTAssertEqual(closed.promptText, "Open your phone to reveal the answer.")

        let half = FortuneModel.mocked(.half, question: question)
        XCTAssertEqual(half.phase, .opening(question: question, progress: 0.5))

        let open = FortuneModel.mocked(.open, question: question)
        let again = FortuneModel.mocked(.open, question: question)
        XCTAssertNotNil(open.phase.answer)
        XCTAssertEqual(open.phase.answer?.text, again.phase.answer?.text, "mocked answers must be repeatable")

        let tap = FortuneModel.mocked(.tap, question: question)
        XCTAssertEqual(tap.mode, .tap)
        XCTAssertEqual(tap.phase, .asking(question: question))
    }

    func testLaunchOptionsReadArguments() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "LaunchOptionsTests"))
        defer { defaults.removePersistentDomain(forName: "LaunchOptionsTests") }
        XCTAssertNil(LaunchOptions(defaults: defaults).mockFold)
        defaults.set("half", forKey: "mockFold")
        defaults.set("Q?", forKey: "mockQuestion")
        let options = LaunchOptions(defaults: defaults)
        XCTAssertEqual(options.mockFold, .half)
        XCTAssertEqual(options.mockQuestion, "Q?")
        defaults.set("sideways", forKey: "mockFold")
        XCTAssertNil(LaunchOptions(defaults: defaults).mockFold)
    }

    func testShareCardRendersAt1080By1350() throws {
        let card = ShareCard(question: "Will the bus be on time?", answer: AnswerSet.original.answers[0])
        let png = try XCTUnwrap(ShareCardView.renderPNG(card))
        let image = try XCTUnwrap(UIImage(data: png)?.cgImage)
        XCTAssertEqual(image.width, 1080)
        XCTAssertEqual(image.height, 1350)
    }

    func testHingeMappingWithoutHingeIsUnavailable() {
        XCTAssertEqual(HingeFoldStateService.posture(for: nil), .unavailable)
    }
}
