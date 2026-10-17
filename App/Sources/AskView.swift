import SwiftUI
import FortuneCore

/// Where the question is typed. On iPhone Duo this shows on the outer display.
struct AskView: View {
    let model: FortuneModel
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 20) {
            PodView(openFraction: 0, answer: nil)
                .frame(maxWidth: 180, maxHeight: 180)

            TextField("Ask a yes or no question", text: Binding(
                get: { model.phase.question },
                set: { model.send(.questionChanged($0)) }
            ), axis: .vertical)
            .lineLimit(1...3)
            .textFieldStyle(.roundedBorder)
            .focused($focused)
            .submitLabel(.done)

            if model.hint == .askFirst {
                Text("Ask your question first.")
                    .font(.footnote)
                    .foregroundStyle(Palette.ochre)
            }

            Text(model.mode == .fold ? "Open your phone to reveal the answer." : "Tap reveal when you are ready.")
                .font(.callout)
                .foregroundStyle(Palette.cream.opacity(0.85))
                .multilineTextAlignment(.center)

            Button("Reveal") {
                focused = false
                model.send(.tapReveal)
            }
            .buttonStyle(.borderedProminent)
            .tint(Palette.wattle)
            .disabled(!model.canReveal)
            .accessibilityHint("Shows the answer without opening the phone")
        }
        .padding(24)
    }
}
