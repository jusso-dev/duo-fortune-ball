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
/// The primary part is artwork, such as the pod, sized to exactly the space
/// its side gets and centred in it, so it shrinks rather than overflowing.
/// The secondary part holds the text and controls and always sits in a
/// scroll view, so large Dynamic Type sizes never clip it and a focused text
/// field keeps its identity when the keyboard appears.
struct FoldAwareLayout<Primary: View, Secondary: View>: View {
    var primary: Primary
    var secondary: Secondary

    init(@ViewBuilder primary: () -> Primary, @ViewBuilder secondary: () -> Secondary) {
        self.primary = primary()
        self.secondary = secondary()
    }

    var body: some View {
        ArrangementView {
            GeometryReader { proxy in
                primary
                    .padding(24)
                    .frame(width: proxy.size.width, height: proxy.size.height)
            }
        } secondary: {
            CentredScroll { secondary.padding(24) }
        }
        .arrangementViewStyle(.split)
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
