import SwiftUI
import FortuneCore

/// The original fortune "seed pod": two shells that part as the phone opens,
/// revealing an answer card.
struct PodView: View {
    var openFraction: Double
    var answer: Answer?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)
            // With Reduce Motion on, the shells stay put and the card
            // cross-fades in instead of the shells swinging apart.
            let motion = reduceMotion ? 0 : openFraction
            // Fully open, the shells still sit inside the pod's own frame,
            // so they never run past the screen edge or the layout margins.
            let spread = size * 0.16 * motion
            ZStack {
                PodShell()
                    .fill(Palette.eucalyptus)
                    .overlay(PodShell().stroke(Palette.wattle, lineWidth: 2))
                    .frame(width: size * 0.5, height: size * 0.8)
                    .rotationEffect(.degrees(-12 * motion))
                    .opacity(reduceMotion ? 1 - openFraction : 1)
                    .offset(x: -size * 0.13 - spread)

                PodShell()
                    .fill(Palette.eucalyptusDeep)
                    .overlay(PodShell().stroke(Palette.wattle, lineWidth: 2))
                    .frame(width: size * 0.5, height: size * 0.8)
                    .scaleEffect(x: -1, y: 1)
                    .rotationEffect(.degrees(12 * motion))
                    .opacity(reduceMotion ? 1 - openFraction : 1)
                    .offset(x: size * 0.13 + spread)

                // In front of the shells, so a long answer is never hidden
                // behind them. It is invisible until the pod opens.
                AnswerCard(answer: answer)
                    .frame(width: size * 0.62, height: size * 0.42)
                    .scaleEffect(0.6 + 0.4 * (reduceMotion ? 1 : openFraction))
                    .opacity(openFraction)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(answer == nil)
    }
}

/// Half of the pod: a leaf like curve, flat on its inner edge.
struct PodShell: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.maxY),
                       control: CGPoint(x: rect.minX - rect.width * 0.4, y: rect.midY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        return p
    }
}

struct AnswerCard: View {
    var answer: Answer?

    var body: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(Palette.cream)
            .shadow(color: Palette.wattle.opacity(0.7), radius: 16)
            .overlay {
                Text(answer?.text ?? "")
                    .font(.system(.headline, design: .serif))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Palette.eucalyptusDeep)
                    .padding(10)
                    .minimumScaleFactor(0.6)
            }
    }
}
