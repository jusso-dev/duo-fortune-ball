import Foundation

/// The seam between the app and the device's fold state.
///
/// The app target implements this by adapting SwiftUI's `onHingeChange`.
/// Tests and previews use `MockFoldStateService`. Devices without a hinge use
/// `UnavailableFoldStateService`.
public protocol FoldStateService: AnyObject, Sendable {
    /// The latest posture.
    var current: FoldPosture { get }
    /// A new stream of postures. It yields `current` first, then every change.
    var updates: AsyncStream<FoldPosture> { get }
}

/// A thread safe `FoldStateService` you push postures into.
///
/// Duplicate postures are not re-sent. Subclass or wrap it to adapt a real
/// source, as the app does with `onHingeChange`.
open class BroadcastFoldStateService: FoldStateService, @unchecked Sendable {
    private let lock = NSLock()
    private var _current: FoldPosture
    private var continuations: [UUID: AsyncStream<FoldPosture>.Continuation] = [:]

    public init(initial: FoldPosture = .unavailable) {
        _current = initial
    }

    deinit {
        for continuation in continuations.values { continuation.finish() }
    }

    public var current: FoldPosture {
        lock.lock()
        defer { lock.unlock() }
        return _current
    }

    public var updates: AsyncStream<FoldPosture> {
        let (stream, continuation) = AsyncStream<FoldPosture>.makeStream(bufferingPolicy: .bufferingNewest(16))
        let id = UUID()
        lock.lock()
        continuations[id] = continuation
        let snapshot = _current
        lock.unlock()
        continuation.yield(snapshot)
        continuation.onTermination = { [weak self] _ in
            guard let self else { return }
            self.lock.lock()
            self.continuations[id] = nil
            self.lock.unlock()
        }
        return stream
    }

    /// Number of live subscribers. Useful in tests.
    public var subscriberCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return continuations.count
    }

    /// Publish a new posture. Returns false when it equals the current one.
    @discardableResult
    public func send(_ posture: FoldPosture) -> Bool {
        lock.lock()
        guard posture != _current else {
            lock.unlock()
            return false
        }
        _current = posture
        let targets = Array(continuations.values)
        lock.unlock()
        for continuation in targets { continuation.yield(posture) }
        return true
    }
}

/// A scriptable fold state for tests, previews and the simulator.
public final class MockFoldStateService: BroadcastFoldStateService, @unchecked Sendable {
    /// Every posture sent, in order, including the initial one.
    public private(set) var history: [FoldPosture]

    public override init(initial: FoldPosture = .closed) {
        history = [initial]
        super.init(initial: initial)
    }

    @discardableResult
    public override func send(_ posture: FoldPosture) -> Bool {
        let changed = super.send(posture)
        if changed { history.append(posture) }
        return changed
    }

    /// Send each posture in order.
    public func play(_ script: [FoldPosture]) {
        for posture in script { send(posture) }
    }

    /// A typical open gesture: closed, a few partial angles, then open.
    public static let openingScript: [FoldPosture] = [
        .closed,
        .partiallyOpen(angleDegrees: 30),
        .partiallyOpen(angleDegrees: 90),
        .partiallyOpen(angleDegrees: 150),
        .open
    ]
}

/// The fallback for iPhones without a hinge. Always `.unavailable`.
public final class UnavailableFoldStateService: FoldStateService, @unchecked Sendable {
    public init() {}

    public var current: FoldPosture { .unavailable }

    public var updates: AsyncStream<FoldPosture> {
        AsyncStream { continuation in
            continuation.yield(.unavailable)
            continuation.finish()
        }
    }
}
