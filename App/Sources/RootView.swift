import SwiftUI
import FortuneCore

struct RootView: View {
    @State private var hinge: HingeFoldStateService
    @State private var model: FortuneModel
    @State private var editing = false
    @State private var planner = FeedbackPlanner()
    @State private var pulse = FeedbackPulse()
    @State private var sounds = SoundPlayer()
    @AppStorage(FeedbackSettings.soundKey) private var soundEnabled = true

    init() {
        let hinge = HingeFoldStateService()
        let store: any AnswerSetStore = (try? FileAnswerSetStore.applicationSupport()) ?? InMemoryAnswerSetStore()
        _hinge = State(initialValue: hinge)
        _model = State(initialValue: FortuneModel(foldService: hinge, store: store))
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Palette.eucalyptusDeep.ignoresSafeArea()
            Group {
                switch model.phase {
                case .asking:
                    AskView(model: model)
                case .opening, .revealed:
                    RevealView(model: model)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Button {
                editing = true
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .foregroundStyle(Palette.wattle)
                    .padding()
            }
            .accessibilityLabel("Answers and settings")
        }
        .feedingHinge(into: hinge)
        .task { await model.observeFold() }
        .onChange(of: model.phase.answer) { _, answer in
            // The reveal can happen with the phone opening and no tap, so
            // tell VoiceOver users the answer straight away.
            guard answer != nil, let text = model.revealAnnouncement else { return }
            AccessibilityNotification.Announcement(text).post()
        }
        .onChange(of: model.phase) { old, new in
            guard let cue = planner.cue(from: old, to: new, mode: model.mode) else { return }
            pulse.fire(cue)
            if soundEnabled, let sound = cue.sound { sounds.play(sound) }
        }
        .sensoryFeedback(trigger: pulse) { _, new in new.cue?.haptic.sensoryFeedback }
        .sheet(isPresented: $editing) { AnswerEditorView(model: model) }
    }
}
