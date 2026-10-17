import SwiftUI
import FortuneCore

struct RootView: View {
    var body: some View {
        Text("Fold Fortune \(FortuneCore.version)")
            .padding()
    }
}
