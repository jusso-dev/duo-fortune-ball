import Foundation
import Observation
import FortuneCore

/// Owns the reveal state machine, the answer set and fold observation.
@MainActor
@Observable
final class FortuneModel {
    private(set) var machine: RevealMachine
    private(set) var answerSet: AnswerSet
    var lastError: AnswerSetError?
    /// True when the last edit could not be written to disk. The edit still
    /// applies for this session.
    private(set) var saveFailed = false
    let foldService: any FoldStateService
    private let store: any AnswerSetStore

    init(
        foldService: any FoldStateService,
        store: any AnswerSetStore,
        generator: any RandomNumberGenerator = SystemRandomNumberGenerator()
    ) {
        let set = store.loadOrOriginal()
        self.foldService = foldService
        self.store = store
        self.answerSet = set
        self.machine = RevealMachine(answers: set.answers, posture: foldService.current, generator: generator)
    }

    var phase: RevealPhase { machine.phase }
    var mode: RevealMode { machine.mode }
    var hint: RevealHint { machine.hint }
    var canReveal: Bool { machine.canReveal }

    /// The instruction under the question field.
    var promptText: String {
        switch mode {
        case .tap:
            "Tap Reveal when you're ready."
        case .fold where machine.foldArmed:
            "Open your phone to reveal the answer."
        case .fold:
            // Already open (for example at launch), so opening won't count.
            "Close and reopen, or tap Reveal."
        }
    }

    /// What VoiceOver reads for the revealed answer, or nil before a reveal.
    var revealAnnouncement: String? { phase.answer.map { "Answer: \($0.text)" } }

    func send(_ event: RevealEvent) {
        machine.handle(event)
    }

    /// Apply an edit to the answer set, persist it and refresh the machine.
    func editAnswers(_ edit: (inout AnswerSet) throws -> Void) {
        var copy = answerSet
        do {
            try edit(&copy)
            do {
                try store.save(copy)
                saveFailed = false
            } catch {
                saveFailed = true
            }
            answerSet = copy
            machine.answers = copy.answers
            lastError = nil
        } catch let error as AnswerSetError {
            lastError = error
        } catch {
            lastError = nil
        }
    }

    /// Run for the lifetime of the view to keep posture in sync.
    func observeFold() async {
        for await posture in foldService.updates {
            machine.handle(.postureChanged(posture))
        }
    }
}
