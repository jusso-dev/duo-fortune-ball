import AVFoundation
import SwiftUI
import FortuneCore

/// A moment the user should feel, and maybe hear.
enum FeedbackCue: Equatable {
    /// The pod started to open (iPhone Duo).
    case opening
    /// The hinge moved another step while opening.
    case tick
    /// The answer appeared.
    case reveal(AnswerTone)

    var haptic: Haptic {
        switch self {
        case .opening, .tick: .tick
        case .reveal(.yes): .success
        case .reveal(.no): .warning
        case .reveal(.maybe), .reveal(.playful): .softImpact
        }
    }

    /// The sound file in the app bundle, or nil for a silent cue.
    var sound: String? {
        switch self {
        case .opening: "pod-creak"
        case .tick: nil
        case .reveal(.yes): "chime-yes"
        case .reveal(.no): "chime-no"
        case .reveal(.maybe), .reveal(.playful): "chime-maybe"
        }
    }
}

/// The haptics the app uses, kept separate from `SensoryFeedback` so the
/// mapping is easy to test.
enum Haptic: Equatable {
    case tick
    case success
    case warning
    case softImpact

    var sensoryFeedback: SensoryFeedback {
        switch self {
        case .tick: .impact(weight: .light, intensity: 0.5)
        case .success: .success
        case .warning: .warning
        case .softImpact: .impact(flexibility: .soft)
        }
    }
}

/// Turns reveal phase changes into feedback cues.
///
/// While opening, ticks are throttled to one per `tickStepDegrees` of hinge
/// travel. Tap mode never opens, so it only gets the reveal cue.
struct FeedbackPlanner {
    static let tickStepDegrees = 15.0
    private var lastTickDegrees: Double?

    mutating func cue(from old: RevealPhase, to new: RevealPhase, mode: RevealMode) -> FeedbackCue? {
        switch new {
        case .asking:
            lastTickDegrees = nil
            return nil
        case .opening(_, let progress):
            guard mode == .fold else { return nil }
            let degrees = progress * 180
            guard let last = lastTickDegrees else {
                lastTickDegrees = degrees
                return .opening
            }
            guard abs(degrees - last) >= Self.tickStepDegrees else { return nil }
            lastTickDegrees = degrees
            return .tick
        case .revealed(_, let answer):
            lastTickDegrees = nil
            if old.answer?.id == answer.id { return nil }
            return .reveal(answer.tone)
        }
    }
}

/// A feedback cue with a running count, so the same cue twice in a row still
/// triggers `sensoryFeedback`.
struct FeedbackPulse: Equatable {
    var count = 0
    var cue: FeedbackCue?

    mutating func fire(_ cue: FeedbackCue) {
        count += 1
        self.cue = cue
    }
}

enum FeedbackSettings {
    /// `UserDefaults` key for the sound toggle. Sound is on by default.
    static let soundKey = "soundEnabled"
}

/// Plays the bundled sounds through an ambient audio session, so the silent
/// switch mutes them and other audio keeps playing. Use it from the main
/// thread only.
final class SoundPlayer {
    private var players: [String: AVAudioPlayer] = [:]
    private var sessionConfigured = false

    func play(_ name: String) {
        if !sessionConfigured {
            try? AVAudioSession.sharedInstance().setCategory(.ambient)
            sessionConfigured = true
        }
        guard let player = player(named: name) else { return }
        player.currentTime = 0
        player.play()
    }

    private func player(named name: String) -> AVAudioPlayer? {
        if let player = players[name] { return player }
        guard let url = Bundle.main.url(forResource: name, withExtension: "wav"),
              let player = try? AVAudioPlayer(contentsOf: url) else { return nil }
        player.prepareToPlay()
        players[name] = player
        return player
    }
}
