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
/// A fold reveal is only armed once the phone has been fully closed, so a
/// wobble at the open end of the hinge (open -> partly open -> open) never
/// reveals. Closing mid way cancels back to asking with the question kept. Closing
/// after a reveal clears the question, ready for the next one. Tap to reveal
/// works in every mode, so it is the fallback on iPhones without a hinge and
/// an accessible alternative on iPhone Duo.
public struct RevealMachine {
    public static let maxQuestionLength = 140
    /// The hinge has to pass this before an armed phone starts opening, so a
    /// settle of a degree or two while typing on the closed phone is ignored.
    public static let openingStartFraction = 20.0 / 180.0
    /// Hysteresis: an opening that falls back below this returns to asking.
    public static let openingCancelFraction = 10.0 / 180.0
    /// An opening at or past this reveals, so a book-style resting angle of
    /// about 155 degrees or more counts without opening flat.
    public static let revealFraction = 0.85

    public private(set) var phase: RevealPhase = .asking(question: "")
    public private(set) var posture: FoldPosture
    public private(set) var hint: RevealHint = .none
    /// True once the phone has been fully closed since the last fold attempt.
    /// Only an armed opening can start a fold reveal.
    public private(set) var foldArmed: Bool
    public var answers: [Answer]
    private var picker: AnswerPicker

    public init(
        answers: [Answer],
        posture: FoldPosture = .unavailable,
        generator: any RandomNumberGenerator = SystemRandomNumberGenerator()
    ) {
        self.answers = answers
        self.posture = posture
        self.foldArmed = posture == .closed
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
            // Asking again while open still needs a close before a fold reveal.
            foldArmed = posture == .closed

        case .postureChanged(let next):
            let previous = posture
            posture = next
            apply(posture: next, previous: previous)
            switch next {
            case .closed: foldArmed = true
            case .unavailable: foldArmed = false
            default: break
            }
        }
    }

    private mutating func apply(posture next: FoldPosture, previous: FoldPosture) {
        switch (phase, next) {
        case (_, .unavailable):
            // Lost the hinge. Drop any half finished opening back to asking.
            if case .opening(let q, _) = phase { phase = .asking(question: q) }

        case (.asking(let q), .partiallyOpen):
            // Only an opening gesture that starts from fully closed counts,
            // and only once it's past a small settle.
            guard foldArmed else { return }
            let progress = next.openFraction()
            guard progress >= Self.openingStartFraction else { return }
            if canReveal {
                if progress >= Self.revealFraction {
                    foldArmed = false
                    reveal()
                } else {
                    phase = .opening(question: q, progress: progress)
                }
            } else {
                // Ask first, then close and open again.
                foldArmed = false
                hint = .askFirst
            }

        case (.asking, .open):
            guard foldArmed else { return }
            foldArmed = false
            if canReveal { reveal() } else { hint = .askFirst }

        case (.opening(let q, _), .partiallyOpen):
            let progress = next.openFraction()
            if progress >= Self.revealFraction {
                reveal()
            } else if progress < Self.openingCancelFraction {
                // Nearly shut again. Back to the ask screen, still armed.
                phase = .asking(question: q)
            } else {
                phase = .opening(question: q, progress: progress)
            }

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
            foldArmed = false
            return
        }
    }
}
