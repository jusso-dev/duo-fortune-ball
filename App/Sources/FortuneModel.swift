import Foundation
import Observation
import FortuneCore

/// Owns the reveal state machine and feeds it fold postures.
@MainActor
@Observable
final class FortuneModel {
    private(set) var machine: RevealMachine
    let foldService: any FoldStateService

    init(foldService: any FoldStateService, answers: [Answer]) {
        self.foldService = foldService
        self.machine = RevealMachine(answers: answers, posture: foldService.current)
    }

    var phase: RevealPhase { machine.phase }
    var mode: RevealMode { machine.mode }
    var hint: RevealHint { machine.hint }
    var canReveal: Bool { machine.canReveal }

    func send(_ event: RevealEvent) {
        machine.handle(event)
    }

    /// Run for the lifetime of the view to keep posture in sync.
    func observeFold() async {
        for await posture in foldService.updates {
            machine.handle(.postureChanged(posture))
        }
    }
}
