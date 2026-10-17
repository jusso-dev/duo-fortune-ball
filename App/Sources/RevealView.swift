import SwiftUI
import FortuneCore

/// The opening and revealed states, usually on the inner display.
struct RevealView: View {
    let model: FortuneModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// The rendered share card for the current reveal, or nil before one.
    @State private var shared: (item: SharedFortune, preview: Image)?

    var body: some View {
        ViewThatFits(in: .vertical) {
            content
            ScrollView { content }
        }
        .task(id: ShareCard(phase: model.phase)) {
            shared = nil
            guard let card = ShareCard(phase: model.phase),
                  let png = ShareCardView.renderPNG(card),
                  let image = UIImage(data: png) else { return }
            shared = (SharedFortune(card: card, png: png), Image(uiImage: image))
        }
    }

    private var content: some View {
        VStack(spacing: 24) {
            Text(model.phase.question)
                .font(.title3)
                .foregroundStyle(Palette.cream)
                .multilineTextAlignment(.center)

            PodView(openFraction: openFraction, answer: model.phase.answer)
                .frame(maxWidth: 420)
                .animation(reduceMotion ? nil : .spring(duration: 0.6, bounce: 0.25), value: openFraction)
                .accessibilityElement(children: .combine)
                .accessibilityLabel(model.revealAnnouncement ?? "Opening")

            if model.phase.answer == nil {
                // Opening: the hinge may rest short of fully open, so always
                // offer a way forward, including for VoiceOver.
                Button("Reveal") { model.send(.tapReveal) }
                    .buttonStyle(.borderedProminent)
                    .tint(Palette.wattle)
                    .foregroundStyle(Palette.eucalyptusDeep)
            } else {
                if model.mode == .fold {
                    Text("Close your phone to ask again.")
                        .font(.callout)
                        .foregroundStyle(Palette.cream.opacity(0.8))
                }
                HStack(spacing: 12) {
                    Button("Ask again") { model.send(.askAgain) }
                        .buttonStyle(.bordered)
                        .tint(Palette.wattle)
                    if let shared {
                        ShareLink(
                            item: shared.item,
                            preview: SharePreview(shared.item.card.title, image: shared.preview)
                        ) {
                            Label("Share", systemImage: "square.and.arrow.up")
                        }
                        .buttonStyle(.bordered)
                        .tint(Palette.wattle)
                    }
                }
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
