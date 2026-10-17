import Foundation

/// The text content of a share card. The app renders it as an image and
/// passes `plainText` alongside for apps that only accept text.
public struct ShareCard: Equatable, Sendable {
    public static let maxQuestionLength = 100
    public static let defaultAppName = "Fold Fortune"

    public let question: String
    public let answer: String
    public let tone: AnswerTone
    public let appName: String

    public init(question: String, answer: Answer, appName: String = ShareCard.defaultAppName) {
        self.question = Self.shorten(question.trimmingCharacters(in: .whitespacesAndNewlines), to: Self.maxQuestionLength)
        self.answer = answer.text
        self.tone = answer.tone
        self.appName = appName
    }

    /// Builds a card from a revealed phase, or nil before a reveal.
    public init?(phase: RevealPhase, appName: String = ShareCard.defaultAppName) {
        guard case .revealed(let question, let answer) = phase else { return nil }
        self.init(question: question, answer: answer, appName: appName)
    }

    public var title: String { "I asked \(appName)" }

    public var plainText: String {
        "I asked: \"\(question)\"\n\(appName) said: \"\(answer)\""
    }

    /// Cuts on a word boundary where possible and adds an ellipsis.
    static func shorten(_ text: String, to limit: Int) -> String {
        guard text.count > limit, limit > 1 else { return text }
        let hard = String(text.prefix(limit - 1))
        if let space = hard.lastIndex(of: " "), hard.distance(from: hard.startIndex, to: space) > limit / 2 {
            return String(hard[..<space]) + "\u{2026}"
        }
        return hard + "\u{2026}"
    }
}
