/// The fold posture of the device, as the app's logic sees it.
///
/// On iPhone Duo the app target maps SwiftUI's `DeviceHinge` into this type:
/// `.closed` -> `.closed`, `.partiallyOpen` -> `.partiallyOpen(angleDegrees:)`,
/// `.fullyOpen` -> `.open`. A nil `DeviceHingeContext.hinge` (any iPhone
/// without a hinge) maps to `.unavailable`, which selects tap to reveal.
public enum FoldPosture: Equatable, Hashable, Sendable {
    case closed
    case partiallyOpen(angleDegrees: Double)
    case open
    case unavailable

    /// True when the device reports a hinge at all.
    public var hasHinge: Bool { self != .unavailable }

    /// How far open the device is, from 0 (closed) to 1 (open).
    ///
    /// `fullOpenDegrees` is the angle treated as fully open. The default of
    /// 180 degrees assumes the hinge angle reads 0 when closed and 180 when
    /// flat. Confirm against the iPhone Duo simulator in Device Hub.
    public func openFraction(fullOpenDegrees: Double = 180) -> Double {
        switch self {
        case .closed:
            return 0
        case .open, .unavailable:
            return 1
        case .partiallyOpen(let degrees):
            guard fullOpenDegrees > 0, degrees.isFinite else { return 0 }
            return min(max(degrees / fullOpenDegrees, 0), 1)
        }
    }
}
