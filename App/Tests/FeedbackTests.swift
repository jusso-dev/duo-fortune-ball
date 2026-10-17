import XCTest
import FortuneCore
@testable import FoldFortune

final class FeedbackTests: XCTestCase {
    private func answer(_ tone: AnswerTone) -> Answer {
        Answer(text: "An answer", tone: tone)
    }

    func testRevealHapticAndSoundFollowTone() {
        XCTAssertEqual(FeedbackCue.reveal(.yes).haptic, .firmImpact)
        XCTAssertEqual(FeedbackCue.reveal(.no).haptic, .heavyImpact)
        XCTAssertEqual(FeedbackCue.reveal(.maybe).haptic, .softImpact)
        XCTAssertEqual(FeedbackCue.reveal(.playful).haptic, .softImpact)
        XCTAssertEqual(FeedbackCue.reveal(.yes).sound, "chime-yes")
        XCTAssertEqual(FeedbackCue.reveal(.no).sound, "chime-no")
        XCTAssertEqual(FeedbackCue.reveal(.maybe).sound, "chime-maybe")
        XCTAssertEqual(FeedbackCue.reveal(.playful).sound, "chime-maybe")
        XCTAssertEqual(FeedbackCue.opening.sound, "pod-creak")
        XCTAssertNil(FeedbackCue.tick.sound)
    }

    func testEverySoundIsBundled() {
        let cues: [FeedbackCue] = [.opening, .tick] + AnswerTone.allCases.map { .reveal($0) }
        for name in cues.compactMap(\.sound) {
            XCTAssertNotNil(Bundle(for: SoundPlayer.self).url(forResource: name, withExtension: "wav"), name)
        }
    }

    func testTicksAreThrottledToFifteenDegrees() {
        var planner = FeedbackPlanner()
        var phase = RevealPhase.asking(question: "Q?")
        var cues: [FeedbackCue?] = []
        for degrees in [25.0, 30, 39, 41, 42, 55, 57, 60] {
            let next = RevealPhase.opening(question: "Q?", progress: degrees / 180)
            cues.append(planner.cue(from: phase, to: next, mode: .fold))
            phase = next
        }
        XCTAssertEqual(cues, [.opening, nil, nil, .tick, nil, nil, .tick, nil])
    }

    func testRevealFiresOnceAndResets() {
        var planner = FeedbackPlanner()
        let yes = answer(.yes)
        let opening = RevealPhase.opening(question: "Q?", progress: 0.3)
        let revealed = RevealPhase.revealed(question: "Q?", answer: yes)
        XCTAssertEqual(planner.cue(from: .asking(question: "Q?"), to: opening, mode: .fold), .opening)
        XCTAssertEqual(planner.cue(from: opening, to: revealed, mode: .fold), .reveal(.yes))
        XCTAssertNil(planner.cue(from: revealed, to: revealed, mode: .fold))
        XCTAssertNil(planner.cue(from: revealed, to: .asking(question: ""), mode: .fold))
        // A fresh opening starts with the opening cue again.
        XCTAssertEqual(planner.cue(from: .asking(question: "Q?"), to: opening, mode: .fold), .opening)
    }

    func testWobbleBackToAskingDoesNotReplayTheCreak() {
        var planner = FeedbackPlanner()
        let asking = RevealPhase.asking(question: "Q?")
        let opening = RevealPhase.opening(question: "Q?", progress: 0.2)
        XCTAssertEqual(planner.cue(from: asking, to: opening, mode: .fold), .opening)
        XCTAssertNil(planner.cue(from: opening, to: asking, mode: .fold))
        XCTAssertEqual(planner.cue(from: asking, to: opening, mode: .fold), .tick)
    }

    func testAllSoundsListsEveryCueSound() {
        let cues: [FeedbackCue] = [.opening, .tick] + AnswerTone.allCases.map { .reveal($0) }
        XCTAssertEqual(Set(cues.compactMap(\.sound)), Set(FeedbackCue.allSounds))
    }

    func testTapModeOnlyGetsTheReveal() {
        var planner = FeedbackPlanner()
        XCTAssertNil(planner.cue(from: .asking(question: ""), to: .asking(question: "Q?"), mode: .tap))
        XCTAssertNil(planner.cue(from: .asking(question: "Q?"), to: .opening(question: "Q?", progress: 0.5), mode: .tap))
        XCTAssertEqual(
            planner.cue(from: .asking(question: "Q?"), to: .revealed(question: "Q?", answer: answer(.no)), mode: .tap),
            .reveal(.no)
        )
    }

    func testPulseChangesForRepeatedCues() {
        var pulse = FeedbackPulse()
        pulse.fire(.tick)
        let first = pulse
        pulse.fire(.tick)
        XCTAssertNotEqual(first, pulse)
    }
}
