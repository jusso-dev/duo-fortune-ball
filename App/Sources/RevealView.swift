import SwiftUI
import FortuneCore

/// The opening and revealed states, usually on the inner display.
struct RevealView: View {
    let model: FortuneModel

    var body: some View {
        VStack(spacing: 24) {
            Text(model.phase.question)
                .font(.title3)
                .foregroundStyle(Palette.cream)
                .multilineTextAlignment(.center)

            PodView(openFraction: openFraction, answer: model.phase.answer)
                .frame(maxWidth: 420)
                .animation(.spring(duration: 0.6, bounce: 0.25), value: openFraction)
                .accessibilityElement(children: .combine)
                .accessibilityLabel(model.phase.answer.map { "Answer: \($0.text)" } ?? "Opening")

            if model.phase.answer != nil {
                Text(model.mode == .fold ? "Close your phone to ask again." : "")
                    .font(.callout)
                    .foregroundStyle(Palette.cream.opacity(0.8))
                Button("Ask again") { model.send(.askAgain) }
                    .buttonStyle(.bordered)
                    .tint(Palette.wattle)
            }
        }
        .padding(24)
    }

    private var openFraction: Double {
        switch model.phase {
        case .asking: 0
        case .opening(_, let progress): progress
        case .revealed: 1
        }
    }
}
