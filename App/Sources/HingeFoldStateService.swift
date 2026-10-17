import SwiftUI
import FortuneCore

/// Adapts SwiftUI's hinge API into FortuneCore's `FoldStateService`.
///
/// Starts as `.unavailable` (tap to reveal). On iPhone Duo the first
/// `onHingeChange` callback switches it to a real posture.
/// API reference: https://developer.apple.com/documentation/swiftui/devicehinge
final class HingeFoldStateService: BroadcastFoldStateService, @unchecked Sendable {
    init() {
        super.init(initial: .unavailable)
    }

    func update(from context: DeviceHingeContext) {
        send(Self.posture(for: context.hinge))
    }

    static func posture(for hinge: DeviceHinge?) -> FoldPosture {
        guard let hinge else { return .unavailable }
        if hinge.status == .closed { return .closed }
        if hinge.status == .fullyOpen { return .open }
        // .partiallyOpen, and any status Apple adds later, use the live angle.
        return .partiallyOpen(angleDegrees: hinge.angle.degrees)
    }
}

extension View {
    /// Feeds hinge changes for this view hierarchy into the given service.
    func feedingHinge(into service: HingeFoldStateService) -> some View {
        onHingeChange { _, newContext in
            service.update(from: newContext)
        }
    }
}
