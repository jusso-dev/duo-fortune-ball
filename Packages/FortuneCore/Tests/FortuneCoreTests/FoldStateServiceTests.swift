import XCTest
@testable import FortuneCore

final class FoldPostureTests: XCTestCase {
    func testHasHinge() {
        XCTAssertTrue(FoldPosture.closed.hasHinge)
        XCTAssertTrue(FoldPosture.partiallyOpen(angleDegrees: 10).hasHinge)
        XCTAssertTrue(FoldPosture.open.hasHinge)
        XCTAssertFalse(FoldPosture.unavailable.hasHinge)
    }

    func testOpenFraction() {
        XCTAssertEqual(FoldPosture.closed.openFraction(), 0)
        XCTAssertEqual(FoldPosture.open.openFraction(), 1)
        XCTAssertEqual(FoldPosture.unavailable.openFraction(), 1)
        XCTAssertEqual(FoldPosture.partiallyOpen(angleDegrees: 90).openFraction(), 0.5, accuracy: 1e-9)
        XCTAssertEqual(FoldPosture.partiallyOpen(angleDegrees: -20).openFraction(), 0)
        XCTAssertEqual(FoldPosture.partiallyOpen(angleDegrees: 400).openFraction(), 1)
        XCTAssertEqual(FoldPosture.partiallyOpen(angleDegrees: .nan).openFraction(), 0)
        XCTAssertEqual(FoldPosture.partiallyOpen(angleDegrees: 60).openFraction(fullOpenDegrees: 120), 0.5, accuracy: 1e-9)
    }
}

final class FoldStateServiceTests: XCTestCase {
    func testMockStartsClosedAndRecordsHistory() {
        let mock = MockFoldStateService()
        XCTAssertEqual(mock.current, .closed)
        mock.play(MockFoldStateService.openingScript)
        XCTAssertEqual(mock.current, .open)
        XCTAssertEqual(mock.history, MockFoldStateService.openingScript)
    }

    func testDuplicatePostureIsIgnored() {
        let mock = MockFoldStateService(initial: .open)
        XCTAssertFalse(mock.send(.open))
        XCTAssertTrue(mock.send(.closed))
        XCTAssertEqual(mock.history, [.open, .closed])
    }

    func testUpdatesYieldCurrentThenChanges() async {
        let mock = MockFoldStateService()
        var iterator = mock.updates.makeAsyncIterator()
        let first = await iterator.next()
        XCTAssertEqual(first, .closed)
        mock.send(.partiallyOpen(angleDegrees: 45))
        mock.send(.open)
        let second = await iterator.next()
        let third = await iterator.next()
        XCTAssertEqual(second, .partiallyOpen(angleDegrees: 45))
        XCTAssertEqual(third, .open)
    }

    func testMultipleSubscribersEachGetUpdates() async {
        let service = BroadcastFoldStateService(initial: .closed)
        var a = service.updates.makeAsyncIterator()
        var b = service.updates.makeAsyncIterator()
        XCTAssertEqual(service.subscriberCount, 2)
        _ = await a.next()
        _ = await b.next()
        service.send(.open)
        let fromA = await a.next()
        let fromB = await b.next()
        XCTAssertEqual(fromA, .open)
        XCTAssertEqual(fromB, .open)
    }

    func testUnavailableServiceYieldsOnceAndFinishes() async {
        let service = UnavailableFoldStateService()
        XCTAssertEqual(service.current, .unavailable)
        var seen: [FoldPosture] = []
        for await posture in service.updates { seen.append(posture) }
        XCTAssertEqual(seen, [.unavailable])
    }

    func testBroadcastDefaultsToUnavailable() {
        XCTAssertEqual(BroadcastFoldStateService().current, .unavailable)
    }
}

final class SeededGeneratorTests: XCTestCase {
    func testSameSeedSameSequence() {
        var a = SeededGenerator(seed: 42)
        var b = SeededGenerator(seed: 42)
        for _ in 0..<10 { XCTAssertEqual(a.next(), b.next()) }
    }

    func testDifferentSeedsDiffer() {
        var a = SeededGenerator(seed: 1)
        var b = SeededGenerator(seed: 2)
        XCTAssertNotEqual(a.next(), b.next())
    }

    func testWorksWithStandardLibraryRandom() {
        var g = SeededGenerator(seed: 7)
        let picks = (0..<100).map { _ in Int.random(in: 0..<5, using: &g) }
        XCTAssertTrue(picks.allSatisfy { (0..<5).contains($0) })
        XCTAssertGreaterThan(Set(picks).count, 1)
    }

    // Regression: the snapshot used to be yielded after the lock was dropped,
    // so a send racing a new subscriber could deliver a newer posture first
    // and then the stale snapshot. Every stream must see angles only rise.
    func testSubscribersRacingSendsNeverSeeAStaleSnapshot() async {
        let service = BroadcastFoldStateService(initial: .partiallyOpen(angleDegrees: 0))
        let streamsLock = NSLock()
        nonisolated(unsafe) var streams: [AsyncStream<FoldPosture>] = []
        let sender = Thread {
            for angle in 1...400 { service.send(.partiallyOpen(angleDegrees: Double(angle))) }
        }
        sender.start()
        DispatchQueue.concurrentPerform(iterations: 64) { _ in
            let stream = service.updates
            streamsLock.lock(); streams.append(stream); streamsLock.unlock()
        }
        while !sender.isFinished { await Task.yield() }
        service.send(.open)
        for stream in streams {
            var last = -1.0
            for await posture in stream {
                guard case .partiallyOpen(let angle) = posture else {
                    XCTAssertEqual(posture, .open)
                    break
                }
                XCTAssertGreaterThan(angle, last, "stale posture delivered out of order")
                last = angle
            }
        }
    }

    func testMockHistoryIsSafeUnderConcurrentSends() {
        let mock = MockFoldStateService(initial: .closed)
        DispatchQueue.concurrentPerform(iterations: 200) { i in
            mock.send(.partiallyOpen(angleDegrees: Double(i + 1)))
        }
        XCTAssertEqual(mock.history.count, 201)
        XCTAssertEqual(mock.history.last, mock.current)
    }
}
