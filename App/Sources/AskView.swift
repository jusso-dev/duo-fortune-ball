import SwiftUI
import FortuneCore

/// Where the question is typed. On iPhone Duo this shows on the outer display.
struct AskView: View {
    let model: FortuneModel
    @FocusState private var focused: Bool

    var body: some View {
        // Usually the outer display, where there is no fold. If the phone
        // is partly open while asking, the pod and the controls go either
        // side of the fold.
        FoldAwareLayout(spacing: 20) {
            PodView(openFraction: 0, answer: nil)
                .frame(maxWidth: 180, maxHeight: 180)
        } secondary: {
            controls
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private var controls: some View {
        VStack(spacing: 20) {
            TextField("Ask a yes or no question", text: Binding(
                get: { model.phase.question },
                set: { text in
                    // A vertical field turns Return into a new line. Treat it
                    // as Done instead, and flatten pasted line breaks.
                    if text.contains(where: \.isNewline) {
                        let flat = text.split(whereSeparator: \.isNewline).joined(separator: " ")
                        model.send(.questionChanged(flat))
                        if text.last?.isNewline == true { focused = false }
                    } else {
                        model.send(.questionChanged(text))
                    }
                }
            ), axis: .vertical)
            .lineLimit(1...3)
            .textFieldStyle(.roundedBorder)
            .focused($focused)
            .submitLabel(.done)

            if model.hint == .askFirst {
                Text("Ask your question first.")
                    .font(.footnote)
                    // Wattle on eucalyptusDeep is about 4.8:1. Ochre was 2.1:1.
                    .foregroundStyle(Palette.wattle)
            }

            Text(model.promptText)
                .font(.callout)
                .foregroundStyle(Palette.cream.opacity(0.85))
                .multilineTextAlignment(.center)

            Button("Reveal") {
                focused = false
                model.send(.tapReveal)
            }
            .buttonStyle(.borderedProminent)
            .tint(Palette.wattle)
            // A dark label on wattle is about 11:1. The default white was 1.9:1.
            .foregroundStyle(Palette.eucalyptusDeep)
            .disabled(!model.canReveal)
            .accessibilityHint("Shows the answer without opening the phone")
        }
    }
}
