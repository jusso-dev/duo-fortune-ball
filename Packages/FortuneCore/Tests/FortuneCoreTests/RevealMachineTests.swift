import XCTest
@testable import FortuneCore

final class AnswerPickerTests: XCTestCase {
    let answers = (0..<5).map { Answer(text: "a\($0)", tone: .yes) }

    func testEmptyReturnsNil() {
        var picker = AnswerPicker(generator: SeededGenerator(seed: 1))
        XCTAssertNil(picker.pick(from: []))
    }

    func testDeterministicWithSeed() {
        var a = AnswerPicker(generator: SeededGenerator(seed: 9))
        var b = AnswerPicker(generator: SeededGenerator(seed: 9))
        for _ in 0..<20 { XCTAssertEqual(a.pick(from: answers), b.pick(from: answers)) }
    }

    func testNeverRepeatsBackToBack() {
        var picker = AnswerPicker(generator: SeededGenerator(seed: 3))
        var last: Answer?
        for _ in 0..<200 {
            let next = picker.pick(from: answers)
            XCTAssertNotEqual(next, last)
            last = next
        }
    }

    func testSingleAnswerCanRepeat() {
        var picker = AnswerPicker(generator: SeededGenerator(seed: 3))
        let only = [Answer(text: "only", tone: .maybe)]
        XCTAssertEqual(picker.pick(from: only), only[0])
        XCTAssertEqual(picker.pick(from: only), only[0])
    }
}

final class RevealMachineTests: XCTestCase {
    let answers = [
        Answer(text: "one", tone: .yes),
        Answer(text: "two", tone: .no),
        Answer(text: "three", tone: .maybe)
    ]

    func makeFold() -> RevealMachine {
        RevealMachine(answers: answers, posture: .closed, generator: SeededGenerator(seed: 11))
    }

    func testModeFollowsHinge() {
        XCTAssertEqual(makeFold().mode, .fold)
        XCTAssertEqual(RevealMachine(answers: answers).mode, .tap)
    }

    func testFullFoldLoop() {
        var m = makeFold()
        m.handle(.questionChanged("Will it rain tomorrow?"))
        XCTAssertEqual(m.phase, .asking(question: "Will it rain tomorrow?"))
        m.handle(.postureChanged(.partiallyOpen(angleDegrees: 45)))
        XCTAssertEqual(m.phase, .opening(question: "Will it rain tomorrow?", progress: 0.25))
        m.handle(.postureChanged(.partiallyOpen(angleDegrees: 135)))
        XCTAssertEqual(m.phase, .opening(question: "Will it rain tomorrow?", progress: 0.75))
        m.handle(.postureChanged(.open))
        guard case .revealed(let q, let a) = m.phase else { return XCTFail("not revealed") }
        XCTAssertEqual(q, "Will it rain tomorrow?")
        XCTAssertTrue(answers.contains(a))
        m.handle(.postureChanged(.closed))
        XCTAssertEqual(m.phase, .asking(question: ""))
    }

    func testMockScriptDrivesReveal() {
        var m = makeFold()
        m.handle(.questionChanged("Coffee?"))
        for posture in MockFoldStateService.openingScript { m.handle(.postureChanged(posture)) }
        XCTAssertNotNil(m.phase.answer)
    }

    func testJumpStraightFromClosedToOpenReveals() {
        var m = makeFold()
        m.handle(.questionChanged("Beach today?"))
        m.handle(.postureChanged(.open))
        XCTAssertNotNil(m.phase.answer)
    }

    func testClosingMidwayCancelsAndKeepsQuestion() {
        var m = makeFold()
        m.handle(.questionChanged("Pizza?"))
        m.handle(.postureChanged(.partiallyOpen(angleDegrees: 60)))
        m.handle(.postureChanged(.closed))
        XCTAssertEqual(m.phase, .asking(question: "Pizza?"))
    }

    func testOpeningWithoutQuestionHintsAndDoesNotReveal() {
        var m = makeFold()
        m.handle(.postureChanged(.partiallyOpen(angleDegrees: 30)))
        XCTAssertEqual(m.hint, .askFirst)
        m.handle(.postureChanged(.open))
        XCTAssertEqual(m.phase, .asking(question: ""))
        m.handle(.questionChanged("Now?"))
        XCTAssertEqual(m.hint, .none)
    }

    func testWhitespaceQuestionCannotReveal() {
        var m = makeFold()
        m.handle(.questionChanged("   \n "))
        XCTAssertFalse(m.canReveal)
        m.handle(.tapReveal)
        XCTAssertEqual(m.hint, .askFirst)
        XCTAssertNil(m.phase.answer)
    }

    func testRevealTrimsQuestion() {
        var m = RevealMachine(answers: answers, generator: SeededGenerator(seed: 1))
        m.handle(.questionChanged("  Tea?  "))
        m.handle(.tapReveal)
        XCTAssertEqual(m.phase.question, "Tea?")
    }

    func testQuestionIsCapped() {
        var m = makeFold()
        m.handle(.questionChanged(String(repeating: "x", count: 500)))
        XCTAssertEqual(m.phase.question.count, RevealMachine.maxQuestionLength)
    }

    func testOpenOnLaunchDoesNotAutoReveal() {
        // App launched with the phone already open: user types, then must tap
        // or close and reopen.
        var m = RevealMachine(answers: answers, posture: .open, generator: SeededGenerator(seed: 2))
        m.handle(.questionChanged("Swim?"))
        m.handle(.postureChanged(.open))
        XCTAssertNil(m.phase.answer)
        m.handle(.tapReveal)
        XCTAssertNotNil(m.phase.answer)
    }

    func testPartialWithoutClosedFirstDoesNotStartOpening() {
        var m = RevealMachine(answers: answers, posture: .open, generator: SeededGenerator(seed: 2))
        m.handle(.questionChanged("Run?"))
        m.handle(.postureChanged(.partiallyOpen(angleDegrees: 100)))
        XCTAssertEqual(m.phase, .asking(question: "Run?"))
    }

    func testTapRevealFallback() {
        var m = RevealMachine(answers: answers, generator: SeededGenerator(seed: 5))
        XCTAssertEqual(m.mode, .tap)
        m.handle(.questionChanged("Should I learn the ukulele?"))
        m.handle(.tapReveal)
        XCTAssertNotNil(m.phase.answer)
        let first = m.phase.answer
        m.handle(.tapReveal)
        XCTAssertEqual(m.phase.answer, first, "tapping again does not reroll")
        m.handle(.askAgain)
        XCTAssertEqual(m.phase, .asking(question: ""))
    }

    func testQuestionEditsIgnoredOutsideAsking() {
        var m = RevealMachine(answers: answers, generator: SeededGenerator(seed: 5))
        m.handle(.questionChanged("A?"))
        m.handle(.tapReveal)
        m.handle(.questionChanged("B?"))
        XCTAssertEqual(m.phase.question, "A?")
    }

    func testLosingHingeMidOpeningFallsBackToAsking() {
        var m = makeFold()
        m.handle(.questionChanged("Q?"))
        m.handle(.postureChanged(.partiallyOpen(angleDegrees: 20)))
        m.handle(.postureChanged(.unavailable))
        XCTAssertEqual(m.phase, .asking(question: "Q?"))
        XCTAssertEqual(m.mode, .tap)
    }

    func testNoAnswersCannotReveal() {
        var m = RevealMachine(answers: [], generator: SeededGenerator(seed: 5))
        m.handle(.questionChanged("Q?"))
        XCTAssertFalse(m.canReveal)
        m.handle(.tapReveal)
        XCTAssertNil(m.phase.answer)
    }

    func testDeterministicRevealWithSeed() {
        func run() -> Answer? {
            var m = RevealMachine(answers: answers, generator: SeededGenerator(seed: 77))
            m.handle(.questionChanged("Same?"))
            m.handle(.tapReveal)
            return m.phase.answer
        }
        XCTAssertEqual(run(), run())
    }

    // Regression: SE3 review High. A wobble at the open end of the hinge
    // (open -> partly open -> open) must not reveal without a full close.
    func testWobbleAtOpenEndDoesNotReveal() {
        var m = RevealMachine(answers: answers, posture: .open, generator: SeededGenerator(seed: 4))
        m.handle(.questionChanged("Wobble?"))
        m.handle(.postureChanged(.partiallyOpen(angleDegrees: 175)))
        m.handle(.postureChanged(.open))
        XCTAssertNil(m.phase.answer)
        XCTAssertEqual(m.phase, .asking(question: "Wobble?"))
    }

    func testWobbleAfterAskAgainWhileOpenDoesNotReveal() {
        var m = makeFold()
        m.handle(.questionChanged("First?"))
        m.handle(.postureChanged(.open))
        XCTAssertNotNil(m.phase.answer)
        m.handle(.askAgain)
        m.handle(.questionChanged("Second?"))
        m.handle(.postureChanged(.partiallyOpen(angleDegrees: 170)))
        m.handle(.postureChanged(.open))
        XCTAssertNil(m.phase.answer)
        // A full close then open reveals as normal.
        m.handle(.postureChanged(.closed))
        m.handle(.postureChanged(.open))
        XCTAssertNotNil(m.phase.answer)
    }

    func testHintedOpeningNeedsACloseBeforeRevealing() {
        var m = makeFold()
        m.handle(.postureChanged(.partiallyOpen(angleDegrees: 40)))
        XCTAssertEqual(m.hint, .askFirst)
        m.handle(.questionChanged("Typed while half open?"))
        m.handle(.postureChanged(.open))
        XCTAssertNil(m.phase.answer, "must close before a fold reveal")
        m.handle(.postureChanged(.closed))
        m.handle(.postureChanged(.partiallyOpen(angleDegrees: 90)))
        m.handle(.postureChanged(.open))
        XCTAssertNotNil(m.phase.answer)
    }

    func testRegainingHingeWhileOpenIsNotArmed() {
        var m = makeFold()
        m.handle(.questionChanged("Q?"))
        m.handle(.postureChanged(.unavailable))
        m.handle(.postureChanged(.partiallyOpen(angleDegrees: 120)))
        m.handle(.postureChanged(.open))
        XCTAssertNil(m.phase.answer)
    }
}
