import SwiftUI
import CoreTransferable
import UniformTypeIdentifiers
import FortuneCore

/// The image shared after a reveal: the question, the open pod with the
/// answer card, and the app name, in the app's own palette.
///
/// Laid out at 360 by 450 points and rendered at @3x, so the image is
/// 1080 by 1350 pixels.
struct ShareCardView: View {
    static let pointSize = CGSize(width: 360, height: 450)
    static let scale: CGFloat = 3

    let card: ShareCard

    var body: some View {
        VStack(spacing: 14) {
            Text(card.title)
                .font(.footnote.weight(.semibold))
                .textCase(.uppercase)
                .tracking(1.2)
                .foregroundStyle(Palette.wattle)

            Text(card.question)
                .font(.system(.title3, design: .serif))
                .foregroundStyle(Palette.cream)
                .multilineTextAlignment(.center)
                .lineLimit(4)
                .minimumScaleFactor(0.7)

            PodView(openFraction: 1, answer: Answer(text: card.answer, tone: card.tone))
                .frame(maxWidth: 300, maxHeight: 300)

            Text(card.appName)
                .font(.system(.headline, design: .serif))
                .foregroundStyle(Palette.wattle)
        }
        .padding(28)
        .frame(width: Self.pointSize.width, height: Self.pointSize.height)
        .background(
            LinearGradient(
                colors: [Palette.eucalyptus, Palette.eucalyptusDeep],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    /// Renders the card as a PNG at the default Dynamic Type size, or nil if
    /// rendering fails.
    @MainActor
    static func renderPNG(_ card: ShareCard) -> Data? {
        let renderer = ImageRenderer(
            content: ShareCardView(card: card)
                .environment(\.dynamicTypeSize, .large)
        )
        renderer.proposedSize = ProposedViewSize(pointSize)
        renderer.scale = scale
        return renderer.uiImage?.pngData()
    }
}

/// What the share sheet receives: the card image, with the plain text as a
/// fallback for apps that only take text.
struct SharedFortune: Transferable, Sendable {
    let card: ShareCard
    let png: Data

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .png) { $0.png }
        ProxyRepresentation(exporting: \.card.plainText)
    }
}
