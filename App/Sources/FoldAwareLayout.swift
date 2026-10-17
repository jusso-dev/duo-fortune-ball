import SwiftUI

/// Lays out a screen's two parts so nothing sits in the iPhone Duo fold.
///
/// Normally the parts stack vertically, or sit side by side when height is
/// compact (an iPhone in landscape), following size classes rather than the
/// device type as the Human Interface Guidelines advise. When a fold divides
/// the view (iPhone Duo partially open), an `ArrangementView` puts each part
/// on its own side of the fold, following Apple's guidance in "Preparing your
/// app for iPhone Duo". Each part scrolls on its own if it doesn't fit, so
/// large Dynamic Type sizes never clip.
struct FoldAwareLayout<Primary: View, Secondary: View>: View {
    var spacing: CGFloat
    var primary: Primary
    var secondary: Secondary
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    init(
        spacing: CGFloat = 20,
        @ViewBuilder primary: () -> Primary,
        @ViewBuilder secondary: () -> Secondary
    ) {
        self.spacing = spacing
        self.primary = primary()
        self.secondary = secondary()
    }

    var body: some View {
        GeometryReader { proxy in
            Group {
                // The fold region is active only while partially open. Fully
                // open, the inner display is one flat screen.
                if proxy.reservedRegions(kind: .division).contains(where: \.isActive) {
                    ArrangementView {
                        FitOrScroll { primary.padding(24) }
                    } secondary: {
                        FitOrScroll { secondary.padding(24) }
                    }
                    .arrangementViewStyle(.split)
                } else if verticalSizeClass == .compact {
                    HStack(spacing: spacing) {
                        FitOrScroll { primary }
                        FitOrScroll { secondary }
                    }
                    .padding(24)
                } else {
                    FitOrScroll {
                        VStack(spacing: spacing) {
                            primary
                            secondary
                        }
                        .padding(24)
                    }
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }
}

/// Shows content at its natural size, or in a scroll view when it's too tall.
struct FitOrScroll<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        ViewThatFits(in: .vertical) {
            content
            ScrollView { content }
        }
    }
}
