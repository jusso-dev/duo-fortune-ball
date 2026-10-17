import SwiftUI

/// Lays out a screen's two parts so nothing sits in the iPhone Duo fold.
///
/// An `ArrangementView` with the split style does the work, as Apple's
/// "Preparing your app for iPhone Duo" recommends. It stacks the parts when
/// the view is taller than it is wide, puts them side by side when it's
/// wider (an iPhone in landscape), and when the fold divides the view
/// (iPhone Duo partly open) it puts each part on its own side of the fold.
/// It is always the same view, so opening or folding the phone animates
/// rather than rebuilding the screen.
///
/// The primary part is flexible artwork, such as the pod, that shrinks to
/// the space it gets and only scrolls if its text alone is too tall. The
/// secondary part holds the controls and always sits in a scroll view, so
/// large Dynamic Type sizes never clip it and a focused text field keeps
/// its identity when the keyboard appears.
struct FoldAwareLayout<Primary: View, Secondary: View>: View {
    var primary: Primary
    var secondary: Secondary

    init(@ViewBuilder primary: () -> Primary, @ViewBuilder secondary: () -> Secondary) {
        self.primary = primary()
        self.secondary = secondary()
    }

    var body: some View {
        ArrangementView {
            FitOrScroll { primary.padding(24) }
        } secondary: {
            CentredScroll { secondary.padding(24) }
        }
        .arrangementViewStyle(.split)
    }
}

/// Shows content in the space it's given, letting flexible views such as
/// the pod shrink, or in a scroll view when even the fixed parts don't fit.
struct FitOrScroll<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        ViewThatFits(in: .vertical) {
            content
            ScrollView { content }
        }
    }
}

/// Centres content in the space it's given and scrolls when it's taller.
///
/// It is always a scroll view, so content such as a focused text field keeps
/// its identity when the keyboard shrinks the space.
struct CentredScroll<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                content
                    .frame(maxWidth: .infinity, minHeight: proxy.size.height)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
    }
}
