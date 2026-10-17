import XCTest
@testable import FortuneCore

final class ShareCardTests: XCTestCase {
    let answer = Answer(text: "Have a crack, it will work out.", tone: .yes)

    func testPlainText() {
        let card = ShareCard(question: "  Should I start a vegie patch?  ", answer: answer)
        XCTAssertEqual(card.question, "Should I start a vegie patch?")
        XCTAssertEqual(card.plainText, "I asked: \"Should I start a vegie patch?\"\nFold Fortune said: \"Have a crack, it will work out.\"")
        XCTAssertEqual(card.title, "I asked Fold Fortune")
        XCTAssertEqual(card.tone, .yes)
    }

    func testCustomAppName() {
        XCTAssertTrue(ShareCard(question: "Q?", answer: answer, appName: "Pod").plainText.contains("Pod said"))
    }

    func testLongQuestionShortensOnWordBoundary() {
        let long = Array(repeating: "word", count: 40).joined(separator: " ")
        let card = ShareCard(question: long, answer: answer)
        XCTAssertLessThanOrEqual(card.question.count, ShareCard.maxQuestionLength)
        XCTAssertTrue(card.question.hasSuffix("word\u{2026}"))
    }

    func testLongQuestionWithoutSpacesHardCuts() {
        let card = ShareCard(question: String(repeating: "x", count: 300), answer: answer)
        XCTAssertEqual(card.question.count, ShareCard.maxQuestionLength)
        XCTAssertTrue(card.question.hasSuffix("\u{2026}"))
    }

    func testFromPhase() {
        XCTAssertNil(ShareCard(phase: .asking(question: "Q?")))
        XCTAssertNil(ShareCard(phase: .opening(question: "Q?", progress: 0.5)))
        XCTAssertEqual(ShareCard(phase: .revealed(question: "Q?", answer: answer))?.answer, answer.text)
    }
}
