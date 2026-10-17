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

    init(options: LaunchOptions = LaunchOptions()) {
        let hinge = HingeFoldStateService()
        _hinge = State(initialValue: hinge)
        if let fold = options.mockFold {
            _model = State(initialValue: .mocked(fold, question: options.mockQuestion))
        } else {
            let store: any AnswerSetStore = (try? FileAnswerSetStore.applicationSupport()) ?? InMemoryAnswerSetStore()
            _model = State(initialValue: FortuneModel(foldService: hinge, store: store))
        }
    }

    var body: some View {
        // A navigation stack gives the answers button a real toolbar, which
        // iPhone Duo can show as a vertical bar beside the content.
        NavigationStack {
            Group {
                switch model.phase {
                case .asking:
                    AskView(model: model)
                case .opening, .revealed:
                    RevealView(model: model)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background { Palette.eucalyptusDeep.ignoresSafeArea() }
            .toolbar {
                // An icon and a title, so the item can show in a vertical
                // bar (icon), a horizontal bar, or the overflow menu.
                ToolbarItem(placement: .topBarPinnedTrailing) {
                    Button("Answers", systemImage: "slider.horizontal.3") { editing = true }
                        .tint(Palette.wattle)
                        .accessibilityHint("Edit the answers and turn sounds on or off")
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
        }
        // The palette is dark, so keep the status bar and system controls
        // light on it whatever the system appearance.
        .preferredColorScheme(.dark)
        .feedingHinge(into: hinge)
        .task { await model.observeFold() }
        .task { if soundEnabled { sounds.preload(FeedbackCue.allSounds) } }
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
