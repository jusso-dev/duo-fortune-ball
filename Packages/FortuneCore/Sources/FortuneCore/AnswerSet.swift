import Foundation

/// Why an edit to an answer set was refused.
public enum AnswerSetError: Error, Equatable, Sendable {
    case emptyText
    case textTooLong(max: Int)
    case duplicate
    case notFound
    case wouldBeEmpty
}

/// A named, editable list of answers.
public struct AnswerSet: Codable, Equatable, Sendable {
    public static let maxAnswerLength = 80
    public static let currentSchemaVersion = 1

    public var schemaVersion: Int
    public var name: String
    public private(set) var answers: [Answer]

    public init(name: String, answers: [Answer]) {
        self.schemaVersion = Self.currentSchemaVersion
        self.name = name
        self.answers = answers
    }

    public func answers(withTone tone: AnswerTone) -> [Answer] {
        answers.filter { $0.tone == tone }
    }

    @discardableResult
    public mutating func add(_ text: String, tone: AnswerTone) throws -> Answer {
        let clean = try validate(text, excluding: nil)
        let answer = Answer(text: clean, tone: tone)
        answers.append(answer)
        return answer
    }

    public mutating func update(id: UUID, text: String, tone: AnswerTone) throws {
        guard let index = answers.firstIndex(where: { $0.id == id }) else { throw AnswerSetError.notFound }
        let clean = try validate(text, excluding: id)
        answers[index].text = clean
        answers[index].tone = tone
    }

    public mutating func remove(id: UUID) throws {
        guard let index = answers.firstIndex(where: { $0.id == id }) else { throw AnswerSetError.notFound }
        guard answers.count > 1 else { throw AnswerSetError.wouldBeEmpty }
        answers.remove(at: index)
    }

    public mutating func move(fromOffsets source: IndexSet, toOffset destination: Int) {
        // Same semantics as Array.move(fromOffsets:toOffset:) in SwiftUI, without importing it.
        let moving = source.sorted().map { answers[$0] }
        var remaining = answers
        for index in source.sorted(by: >) { remaining.remove(at: index) }
        let shift = source.filter { $0 < destination }.count
        let insertAt = min(max(destination - shift, 0), remaining.count)
        remaining.insert(contentsOf: moving, at: insertAt)
        answers = remaining
    }

    /// Restore the built in original answers.
    public mutating func resetToOriginal() {
        self = .original
    }

    private func validate(_ text: String, excluding id: UUID?) throws -> String {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { throw AnswerSetError.emptyText }
        guard clean.count <= Self.maxAnswerLength else { throw AnswerSetError.textTooLong(max: Self.maxAnswerLength) }
        let lower = clean.lowercased()
        if answers.contains(where: { $0.id != id && $0.text.lowercased() == lower }) {
            throw AnswerSetError.duplicate
        }
        return clean
    }
}

extension AnswerSet {
    /// The built in answers. All wording is original to this project.
    public static let original = AnswerSet(name: "Original", answers: [
        Answer(text: "Yes, and sooner than you think.", tone: .yes),
        Answer(text: "Too right.", tone: .yes),
        Answer(text: "The hinge says go.", tone: .yes),
        Answer(text: "Have a crack, it will work out.", tone: .yes),
        Answer(text: "Everything lines up for this one.", tone: .yes),
        Answer(text: "Sleep on it and look again.", tone: .maybe),
        Answer(text: "Half open, half shut. Could go either way.", tone: .maybe),
        Answer(text: "Ask a mate first.", tone: .maybe),
        Answer(text: "Still unfolding. Give it a day.", tone: .maybe),
        Answer(text: "Flip a coin, then notice how you feel.", tone: .maybe),
        Answer(text: "Not this time.", tone: .no),
        Answer(text: "Give it a miss.", tone: .no),
        Answer(text: "Nah, let that one go.", tone: .no),
        Answer(text: "The pod stays shut on that.", tone: .no),
        Answer(text: "Save your energy for something better.", tone: .no),
        Answer(text: "Only if there are snacks.", tone: .playful),
        Answer(text: "Put the kettle on first.", tone: .playful),
        Answer(text: "The wattle is nodding. Make of that what you will.", tone: .playful)
    ])
}
