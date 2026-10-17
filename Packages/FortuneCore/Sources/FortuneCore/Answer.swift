import Foundation

/// The mood of an answer. Used for colour and haptic choice in the app.
public enum AnswerTone: String, Codable, CaseIterable, Sendable {
    case yes
    case maybe
    case no
    case playful
}

/// One possible answer.
public struct Answer: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var text: String
    public var tone: AnswerTone

    public init(id: UUID = UUID(), text: String, tone: AnswerTone) {
        self.id = id
        self.text = text
        self.tone = tone
    }
}

/// Picks answers using an injected random number generator.
///
/// When there is more than one answer it never repeats the previous pick, so
/// asking twice in a row always feels fresh.
public struct AnswerPicker {
    public private(set) var lastPickedID: UUID?
    private var generator: any RandomNumberGenerator

    public init(generator: any RandomNumberGenerator = SystemRandomNumberGenerator()) {
        self.generator = generator
    }

    public mutating func pick(from answers: [Answer]) -> Answer? {
        guard !answers.isEmpty else { return nil }
        var pool = answers
        if pool.count > 1, let last = lastPickedID {
            pool.removeAll { $0.id == last }
        }
        let index = Int.random(in: 0..<pool.count, using: &generator)
        let choice = pool[index]
        lastPickedID = choice.id
        return choice
    }
}
