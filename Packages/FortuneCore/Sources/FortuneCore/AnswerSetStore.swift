import Foundation

/// Persists the user's answer set.
public protocol AnswerSetStore: Sendable {
    /// Returns nil when nothing has been saved yet.
    func load() throws -> AnswerSet?
    func save(_ set: AnswerSet) throws
    func clear() throws
}

extension AnswerSetStore {
    /// The saved set, or the original set when nothing is saved or the file
    /// cannot be read. A corrupt file never blocks the app.
    public func loadOrOriginal() -> AnswerSet {
        guard let saved = try? load(), !saved.answers.isEmpty else { return .original }
        return saved
    }
}

/// Stores the answer set as JSON in a file, written atomically.
public struct FileAnswerSetStore: AnswerSetStore {
    public let url: URL

    public init(url: URL) {
        self.url = url
    }

    /// `<Application Support>/AnswerSet.json`, creating the folder if needed.
    public static func applicationSupport(fileManager: FileManager = .default) throws -> FileAnswerSetStore {
        let base = try fileManager.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        return FileAnswerSetStore(url: base.appendingPathComponent("AnswerSet.json"))
    }

    public func load() throws -> AnswerSet? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(AnswerSet.self, from: data)
    }

    public func save(_ set: AnswerSet) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(set)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
    }

    public func clear() throws {
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
    }
}

/// An in memory store for tests and previews.
public final class InMemoryAnswerSetStore: AnswerSetStore, @unchecked Sendable {
    private let lock = NSLock()
    private var stored: AnswerSet?

    public init(_ initial: AnswerSet? = nil) {
        stored = initial
    }

    public func load() throws -> AnswerSet? {
        lock.lock(); defer { lock.unlock() }
        return stored
    }

    public func save(_ set: AnswerSet) throws {
        lock.lock(); defer { lock.unlock() }
        stored = set
    }

    public func clear() throws {
        lock.lock(); defer { lock.unlock() }
        stored = nil
    }
}
