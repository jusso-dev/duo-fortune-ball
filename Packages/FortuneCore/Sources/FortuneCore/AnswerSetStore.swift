import Foundation

/// Persists the user's answer set.
public protocol AnswerSetStore: Sendable {
    /// Returns nil when nothing has been saved yet.
    func load() throws -> AnswerSet?
    func save(_ set: AnswerSet) throws
    func clear() throws
    /// The last good copy kept before the most recent save, if any.
    func loadBackup() throws -> AnswerSet?
}

/// Why the store refused to read or write.
public enum AnswerSetStoreError: Error, Equatable, Sendable {
    /// The saved file was written by a newer version of the app.
    case unsupportedSchemaVersion(Int)
}

extension AnswerSetStore {
    public func loadBackup() throws -> AnswerSet? { nil }

    /// The saved set, then the backup, then the original set. A corrupt file
    /// never blocks the app.
    public func loadOrOriginal() -> AnswerSet {
        if let saved = try? load(), !saved.answers.isEmpty { return saved }
        if let backup = try? loadBackup(), !backup.answers.isEmpty { return backup }
        return .original
    }
}

/// Stores the answer set as JSON in a file, written atomically.
///
/// Before each save the previous good file is copied to `<name>.bak`. A file
/// that can't be read is moved to `<name>.unreadable` rather than overwritten,
/// and a file from a newer schema version is never overwritten.
public struct FileAnswerSetStore: AnswerSetStore {
    public let url: URL

    public init(url: URL) {
        self.url = url
    }

    public var backupURL: URL { url.appendingPathExtension("bak") }
    public var unreadableURL: URL { url.appendingPathExtension("unreadable") }

    /// `<Application Support>/AnswerSet.json`, creating the folder if needed.
    public static func applicationSupport(fileManager: FileManager = .default) throws -> FileAnswerSetStore {
        let base = try fileManager.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        return FileAnswerSetStore(url: base.appendingPathComponent("AnswerSet.json"))
    }

    public func load() throws -> AnswerSet? {
        try Self.read(url)
    }

    public func loadBackup() throws -> AnswerSet? {
        try Self.read(backupURL)
    }

    public func save(_ set: AnswerSet) throws {
        let fm = FileManager.default
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(set)
        try fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        if fm.fileExists(atPath: url.path) {
            do {
                _ = try load()
                try Self.replace(backupURL, withCopyOf: url)
            } catch let error as AnswerSetStoreError {
                // Written by a newer app. Leave it alone.
                throw error
            } catch {
                // Unreadable. Keep it aside instead of losing it.
                if fm.fileExists(atPath: unreadableURL.path) { try fm.removeItem(at: unreadableURL) }
                try fm.moveItem(at: url, to: unreadableURL)
            }
        }
        try data.write(to: url, options: .atomic)
    }

    public func clear() throws {
        for file in [url, backupURL] where FileManager.default.fileExists(atPath: file.path) {
            try FileManager.default.removeItem(at: file)
        }
    }

    private static func read(_ file: URL) throws -> AnswerSet? {
        guard FileManager.default.fileExists(atPath: file.path) else { return nil }
        let data = try Data(contentsOf: file)
        let set = try JSONDecoder().decode(AnswerSet.self, from: data)
        guard set.schemaVersion <= AnswerSet.currentSchemaVersion else {
            throw AnswerSetStoreError.unsupportedSchemaVersion(set.schemaVersion)
        }
        return set
    }

    private static func replace(_ destination: URL, withCopyOf source: URL) throws {
        let fm = FileManager.default
        if fm.fileExists(atPath: destination.path) { try fm.removeItem(at: destination) }
        try fm.copyItem(at: source, to: destination)
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
