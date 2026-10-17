import Foundation

/// Where the ask and reveal loop is up to.
public enum RevealPhase: Equatable, Sendable {
    /// Waiting for a question. On iPhone Duo this is the outer display.
    case asking(question: String)
    /// The phone is opening. `progress` runs from 0 to 1.
    case opening(question: String, progress: Double)
    /// The answer is showing.
    case revealed(question: String, answer: Answer)

    public var question: String {
        switch self {
        case .asking(let q), .opening(let q, _), .revealed(let q, _): q
        }
    }

    public var answer: Answer? {
        if case .revealed(_, let answer) = self { return answer }
        return nil
    }
}

/// How the answer gets revealed on this device.
public enum RevealMode: Equatable, Sendable {
    /// iPhone Duo: close to ask, open to reveal.
    case fold
    /// Any iPhone without a hinge: tap to reveal.
    case tap
}

/// Something the user did or the device reported.
public enum RevealEvent: Equatable, Sendable {
    case questionChanged(String)
    case postureChanged(FoldPosture)
    case tapReveal
    case askAgain
}

/// A gentle prompt for the UI.
public enum RevealHint: Equatable, Sendable {
    case none
    /// The phone was opened (or reveal tapped) before a question was typed.
    case askFirst
}

/// The ask and reveal state machine.
///
/// asking (closed, outer display) -> opening (partially open) -> revealed (open).
/// Closing mid way cancels back to asking with the question kept. Closing
/// after a reveal clears the question, ready for the next one. Tap to reveal
/// works in every mode, so it is the fallback on iPhones without a hinge and
/// an accessible alternative on iPhone Duo.
public struct RevealMachine {
    public static let maxQuestionLength = 140

    public private(set) var phase: RevealPhase = .asking(question: "")
    public private(set) var posture: FoldPosture
    public private(set) var hint: RevealHint = .none
    public var answers: [Answer]
    private var picker: AnswerPicker

    public init(
        answers: [Answer],
        posture: FoldPosture = .unavailable,
        generator: any RandomNumberGenerator = SystemRandomNumberGenerator()
    ) {
        self.answers = answers
        self.posture = posture
        self.picker = AnswerPicker(generator: generator)
    }

    public var mode: RevealMode { posture.hasHinge ? .fold : .tap }

    public var canReveal: Bool {
        if case .revealed = phase { return false }
        return !Self.clean(phase.question).isEmpty && !answers.isEmpty
    }

    /// Trims whitespace and caps the length.
    public static func clean(_ question: String) -> String {
        String(question.trimmingCharacters(in: .whitespacesAndNewlines).prefix(maxQuestionLength))
    }

    public mutating func handle(_ event: RevealEvent) {
        switch event {
        case .questionChanged(let text):
            guard case .asking = phase else { return }
            phase = .asking(question: String(text.prefix(Self.maxQuestionLength)))
            if !Self.clean(text).isEmpty { hint = .none }

        case .tapReveal:
            reveal()

        case .askAgain:
            phase = .asking(question: "")
            hint = .none

        case .postureChanged(let next):
            let previous = posture
            posture = next
            apply(posture: next, previous: previous)
        }
    }

    private mutating func apply(posture next: FoldPosture, previous: FoldPosture) {
        switch (phase, next) {
        case (_, .unavailable):
            // Lost the hinge. Drop any half finished opening back to asking.
            if case .opening(let q, _) = phase { phase = .asking(question: q) }

        case (.asking(let q), .partiallyOpen):
            // Only an opening gesture that starts from closed counts.
            guard previous == .closed else { return }
            if canReveal {
                phase = .opening(question: q, progress: next.openFraction())
            } else {
                hint = .askFirst
            }

        case (.asking, .open):
            guard previous == .closed || isPartial(previous) else { return }
            if canReveal { reveal() } else { hint = .askFirst }

        case (.opening(let q, _), .partiallyOpen):
            phase = .opening(question: q, progress: next.openFraction())

        case (.opening, .open):
            reveal()

        case (.opening(let q, _), .closed):
            phase = .asking(question: q)

        case (.revealed, .closed):
            phase = .asking(question: "")
            hint = .none

        default:
            break
        }
    }

    private func isPartial(_ posture: FoldPosture) -> Bool {
        if case .partiallyOpen = posture { return true }
        return false
    }

    private mutating func reveal() {
        let question = Self.clean(phase.question)
        guard !question.isEmpty else {
            hint = .askFirst
            return
        }
        guard case .revealed = phase else {
            guard let answer = picker.pick(from: answers) else { return }
            phase = .revealed(question: question, answer: answer)
            hint = .none
            return
        }
    }
}
