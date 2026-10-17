import SwiftUI
import FortuneCore

struct RootView: View {
    @State private var hinge: HingeFoldStateService
    @State private var model: FortuneModel

    init() {
        let hinge = HingeFoldStateService()
        _hinge = State(initialValue: hinge)
        _model = State(initialValue: FortuneModel(foldService: hinge, answers: StarterAnswers.all))
    }

    var body: some View {
        ZStack {
            Palette.eucalyptusDeep.ignoresSafeArea()
            switch model.phase {
            case .asking:
                AskView(model: model)
            case .opening, .revealed:
                RevealView(model: model)
            }
        }
        .feedingHinge(into: hinge)
        .task { await model.observeFold() }
    }
}

/// Temporary answers until the customisable answer set lands.
enum StarterAnswers {
    static let all: [Answer] = [
        Answer(text: "Have a crack.", tone: .yes),
        Answer(text: "Sleep on it.", tone: .maybe),
        Answer(text: "Give it a miss.", tone: .no)
    ]
}
