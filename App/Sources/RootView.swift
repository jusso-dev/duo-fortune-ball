import SwiftUI
import FortuneCore

struct RootView: View {
    @State private var hinge: HingeFoldStateService
    @State private var model: FortuneModel
    @State private var editing = false

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
            .accessibilityLabel("Edit answers")
        }
        .feedingHinge(into: hinge)
        .task { await model.observeFold() }
        .onChange(of: model.phase.answer) { _, answer in
            // The reveal can happen with the phone opening and no tap, so
            // tell VoiceOver users the answer straight away.
            guard answer != nil, let text = model.revealAnnouncement else { return }
            AccessibilityNotification.Announcement(text).post()
        }
        .sheet(isPresented: $editing) { AnswerEditorView(model: model) }
    }
}
