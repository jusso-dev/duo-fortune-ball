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
        continuation.onTermination = { [weak self] _ in
            guard let self else { return }
            self.lock.lock()
            self.continuations[id] = nil
            self.lock.unlock()
        }
        // Register and yield the snapshot under the lock, so a concurrent
        // send can't slip a newer posture in ahead of a stale snapshot.
        lock.lock()
        continuations[id] = continuation
        continuation.yield(_current)
        lock.unlock()
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
        // Yield under the lock so racing sends reach every subscriber in the
        // same order they changed `current`. Yield never blocks.
        for continuation in continuations.values { continuation.yield(posture) }
        lock.unlock()
        return true
    }
}

/// A scriptable fold state for tests, previews and the simulator.
public final class MockFoldStateService: BroadcastFoldStateService, @unchecked Sendable {
    private let historyLock = NSLock()
    private var _history: [FoldPosture]

    /// Every posture sent, in order, including the initial one.
    public var history: [FoldPosture] {
        historyLock.lock()
        defer { historyLock.unlock() }
        return _history
    }

    public override init(initial: FoldPosture = .closed) {
        _history = [initial]
        super.init(initial: initial)
    }

    @discardableResult
    public override func send(_ posture: FoldPosture) -> Bool {
        // Hold the history lock across the send so history order matches
        // the order postures were published.
        historyLock.lock()
        defer { historyLock.unlock() }
        let changed = super.send(posture)
        if changed { _history.append(posture) }
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
