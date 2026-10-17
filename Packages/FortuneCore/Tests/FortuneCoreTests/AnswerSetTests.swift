import XCTest
@testable import FortuneCore

final class AnswerSetTests: XCTestCase {
    func testOriginalSetCoversEveryTone() {
        for tone in AnswerTone.allCases {
            XCTAssertFalse(AnswerSet.original.answers(withTone: tone).isEmpty, "no \(tone) answers")
        }
    }

    func testOriginalSetIsValid() {
        let texts = AnswerSet.original.answers.map { $0.text.lowercased() }
        XCTAssertEqual(Set(texts).count, texts.count, "duplicates")
        for answer in AnswerSet.original.answers {
            XCTAssertFalse(answer.text.isEmpty)
            XCTAssertLessThanOrEqual(answer.text.count, AnswerSet.maxAnswerLength)
        }
    }

    func testOriginalSetAvoidsThirdPartyToyWording() {
        // Guard against stock phrases associated with existing fortune toys.
        let banned = ["it is certain", "outlook good", "reply hazy", "signs point to yes",
                      "my sources say", "very doubtful", "without a doubt", "ask again later",
                      "cannot predict now", "concentrate and ask again", "it is decidedly so",
                      "you may rely on it", "as i see it", "better not tell you now", "don't count on it",
                      "8 ball", "eight ball",
                      // Near paraphrases of the stock "ask again" and "try again" lines.
                      "ask again", "ask me again", "try again", "try once more"]
        for answer in AnswerSet.original.answers {
            let text = answer.text.lowercased()
            for phrase in banned { XCTAssertFalse(text.contains(phrase), "\(answer.text) contains \(phrase)") }
        }
    }

    func testAddTrimsAndValidates() throws {
        var set = AnswerSet(name: "Mine", answers: [])
        let added = try set.add("  Go on then.  ", tone: .yes)
        XCTAssertEqual(added.text, "Go on then.")
        XCTAssertThrowsError(try set.add("   ", tone: .no)) { XCTAssertEqual($0 as? AnswerSetError, .emptyText) }
        XCTAssertThrowsError(try set.add("go on THEN.", tone: .no)) { XCTAssertEqual($0 as? AnswerSetError, .duplicate) }
        XCTAssertThrowsError(try set.add(String(repeating: "x", count: 81), tone: .no)) {
            XCTAssertEqual($0 as? AnswerSetError, .textTooLong(max: 80))
        }
    }

    func testUpdateAndRemove() throws {
        var set = AnswerSet(name: "Mine", answers: [])
        let a = try set.add("One", tone: .yes)
        let b = try set.add("Two", tone: .no)
        try set.update(id: a.id, text: "Uno", tone: .playful)
        XCTAssertEqual(set.answers.first?.text, "Uno")
        XCTAssertEqual(set.answers.first?.tone, .playful)
        try set.update(id: a.id, text: "uno", tone: .yes) // same answer, case change is fine
        XCTAssertThrowsError(try set.update(id: a.id, text: "Two", tone: .yes)) { XCTAssertEqual($0 as? AnswerSetError, .duplicate) }
        XCTAssertThrowsError(try set.update(id: UUID(), text: "x", tone: .yes)) { XCTAssertEqual($0 as? AnswerSetError, .notFound) }
        try set.remove(id: b.id)
        XCTAssertThrowsError(try set.remove(id: a.id)) { XCTAssertEqual($0 as? AnswerSetError, .wouldBeEmpty) }
        XCTAssertThrowsError(try set.remove(id: UUID())) { XCTAssertEqual($0 as? AnswerSetError, .notFound) }
    }

    func testMove() throws {
        var set = AnswerSet(name: "Mine", answers: [])
        for t in ["a", "b", "c", "d"] { try set.add(t, tone: .yes) }
        set.move(fromOffsets: IndexSet(integer: 0), toOffset: 3)
        XCTAssertEqual(set.answers.map(\.text), ["b", "c", "a", "d"])
        set.move(fromOffsets: IndexSet([2, 3]), toOffset: 0)
        XCTAssertEqual(set.answers.map(\.text), ["a", "d", "b", "c"])
    }

    func testResetToOriginal() throws {
        var set = AnswerSet.original
        try set.add("Custom", tone: .yes)
        set.resetToOriginal()
        XCTAssertEqual(set, .original)
    }

    func testCodableRoundTrip() throws {
        var set = AnswerSet.original
        try set.add("Round trip", tone: .maybe)
        let data = try JSONEncoder().encode(set)
        XCTAssertEqual(try JSONDecoder().decode(AnswerSet.self, from: data), set)
    }

    func testCustomSetDrivesReveal() throws {
        var set = AnswerSet(name: "Mine", answers: [])
        try set.add("Only answer", tone: .yes)
        var m = RevealMachine(answers: set.answers, generator: SeededGenerator(seed: 1))
        m.handle(.questionChanged("Q?"))
        m.handle(.tapReveal)
        XCTAssertEqual(m.phase.answer?.text, "Only answer")
    }
}

final class AnswerSetStoreTests: XCTestCase {
    var dir: URL!

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent("fortune-\(UUID().uuidString)")
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: dir)
    }

    func testFileStoreRoundTrip() throws {
        let store = FileAnswerSetStore(url: dir.appendingPathComponent("nested/AnswerSet.json"))
        XCTAssertNil(try store.load())
        XCTAssertEqual(store.loadOrOriginal(), .original)
        var set = AnswerSet.original
        try set.add("Saved answer", tone: .playful)
        try store.save(set)
        XCTAssertEqual(try store.load(), set)
        XCTAssertEqual(FileAnswerSetStore(url: store.url).loadOrOriginal(), set)
        try store.clear()
        XCTAssertNil(try store.load())
        try store.clear() // clearing twice is fine
    }

    func testCorruptFileFallsBackToOriginal() throws {
        let url = dir.appendingPathComponent("AnswerSet.json")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try Data("not json".utf8).write(to: url)
        let store = FileAnswerSetStore(url: url)
        XCTAssertThrowsError(try store.load())
        XCTAssertEqual(store.loadOrOriginal(), .original)
    }

    func testSaveKeepsBackupOfPreviousGoodFile() throws {
        let store = FileAnswerSetStore(url: dir.appendingPathComponent("AnswerSet.json"))
        var first = AnswerSet.original
        try first.add("First save", tone: .yes)
        try store.save(first)
        XCTAssertNil(try store.loadBackup(), "nothing to back up on the first save")
        var second = first
        try second.add("Second save", tone: .no)
        try store.save(second)
        XCTAssertEqual(try store.load(), second)
        XCTAssertEqual(try store.loadBackup(), first)
    }

    func testCorruptFileFallsBackToBackup() throws {
        let store = FileAnswerSetStore(url: dir.appendingPathComponent("AnswerSet.json"))
        var first = AnswerSet.original
        try first.add("Keep me", tone: .playful)
        try store.save(first)
        try store.save(first)
        try Data("not json".utf8).write(to: store.url)
        XCTAssertEqual(store.loadOrOriginal(), first)
    }

    func testSavingOverUnreadableFileKeepsItAside() throws {
        let store = FileAnswerSetStore(url: dir.appendingPathComponent("AnswerSet.json"))
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try Data("half written".utf8).write(to: store.url)
        try store.save(.original)
        XCTAssertEqual(try store.load(), .original)
        XCTAssertEqual(try Data(contentsOf: store.unreadableURL), Data("half written".utf8))
        XCTAssertNil(try store.loadBackup(), "an unreadable file is not a backup")
    }

    func testNewerSchemaIsNeitherLoadedNorOverwritten() throws {
        let store = FileAnswerSetStore(url: dir.appendingPathComponent("AnswerSet.json"))
        var future = AnswerSet(name: "future", answers: [Answer(text: "From the future", tone: .yes)])
        future.schemaVersion = AnswerSet.currentSchemaVersion + 1
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let original = try JSONEncoder().encode(future)
        try original.write(to: store.url)
        XCTAssertThrowsError(try store.load()) { error in
            XCTAssertEqual(error as? AnswerSetStoreError, .unsupportedSchemaVersion(future.schemaVersion))
        }
        XCTAssertEqual(store.loadOrOriginal(), .original)
        XCTAssertThrowsError(try store.save(.original))
        XCTAssertEqual(try Data(contentsOf: store.url), original)
    }

    func testInMemoryStore() throws {
        let store = InMemoryAnswerSetStore()
        XCTAssertEqual(store.loadOrOriginal(), .original)
        let set = AnswerSet(name: "x", answers: [Answer(text: "a", tone: .yes)])
        try store.save(set)
        XCTAssertEqual(try store.load(), set)
        try store.clear()
        XCTAssertNil(try store.load())
    }

    func testEmptySavedSetFallsBackToOriginal() throws {
        let store = InMemoryAnswerSetStore(AnswerSet(name: "empty", answers: []))
        XCTAssertEqual(store.loadOrOriginal(), .original)
    }
}
