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
        // Words of different lengths, so a mid word cut can't pass by luck.
        let words = ["should", "I", "pack", "an", "umbrella", "for", "the", "long", "weekend", "away", "in", "Batemans", "Bay"]
        let long = (0..<6).flatMap { _ in words }.joined(separator: " ")
        for limit in [20, 33, 47, 60, ShareCard.maxQuestionLength] {
            let short = ShareCard.shorten(long, to: limit)
            XCTAssertLessThanOrEqual(short.count, limit)
            XCTAssertTrue(short.hasSuffix("\u{2026}"))
            let kept = String(short.dropLast())
            XCTAssertTrue(long.hasPrefix(kept), "not a prefix at limit \(limit)")
            let next = long[long.index(long.startIndex, offsetBy: kept.count)]
            XCTAssertEqual(next, " ", "cut mid word at limit \(limit): \(short)")
        }
        let card = ShareCard(question: long, answer: answer)
        XCTAssertLessThanOrEqual(card.question.count, ShareCard.maxQuestionLength)
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
