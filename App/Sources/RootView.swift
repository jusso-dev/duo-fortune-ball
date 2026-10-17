import SwiftUI
import FortuneCore

struct RootView: View {
    @State private var hinge = HingeFoldStateService()
    @State private var posture: FoldPosture = .unavailable

    var body: some View {
        Text(describe(posture))
            .padding()
            .feedingHinge(into: hinge)
            .task {
                for await next in hinge.updates { posture = next }
            }
    }

    private func describe(_ posture: FoldPosture) -> String {
        switch posture {
        case .closed: "Closed"
        case .partiallyOpen(let degrees): "Opening \(Int(degrees.rounded())) degrees"
        case .open: "Open"
        case .unavailable: "No hinge, tap to reveal"
        }
    }
}
