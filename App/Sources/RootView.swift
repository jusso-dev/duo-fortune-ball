import SwiftUI
import FortuneCore

struct RootView: View {
    @State private var hinge: HingeFoldStateService
    @State private var model: FortuneModel
    @State private var editing = false

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
            .accessibilityLabel("Edit answers")
        }
        .feedingHinge(into: hinge)
        .task { await model.observeFold() }
        .sheet(isPresented: $editing) { AnswerEditorView(model: model) }
    }
}
