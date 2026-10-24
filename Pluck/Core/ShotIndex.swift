import Foundation
import OSLog

/// What Pluck remembers about shots that the files can't hold, keyed by file path.
/// Saved as a small JSON file in Application Support.
struct ShotIndex: Codable, Equatable {
    /// Pinned shots, in the user's order.
    var pinned: [String] = []
    /// When each shot was last unpinned. Its age for cleanup counts from then.
    var unpinned: [String: Date] = [:]
    /// When Pluck first ran. Cleanup never touches shots taken before this, so
    /// installing Pluck can't sweep away screenshots the user already had.
    var managedSince: Date?

    init() {}

    /// Missing keys load as empty, so an index written by an older version still reads.
    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        pinned = try c.decodeIfPresent([String].self, forKey: .pinned) ?? []
        unpinned = try c.decodeIfPresent([String: Date].self, forKey: .unpinned) ?? [:]
        managedSince = try c.decodeIfPresent(Date.self, forKey: .managedSince)
    }
}

// MARK: - Per-shot entries

extension ShotIndex {
    /// Everything the index holds about one shot, so it can be put back after an undo.
    struct Entry {
        var pinPosition: Int?
        var unpinned: Date?
    }

    func entry(for id: String) -> Entry {
        Entry(pinPosition: pinned.firstIndex(of: id), unpinned: unpinned[id])
    }

    mutating func forget(_ id: String) {
        pinned.removeAll { $0 == id }
        unpinned[id] = nil
    }

    mutating func restore(_ entry: Entry, for id: String) {
        if let position = entry.pinPosition, !pinned.contains(id) {
            pinned.insert(id, at: min(position, pinned.count))
        }
        unpinned[id] = entry.unpinned
    }

    mutating func rename(_ old: String, to new: String) {
        let moved = entry(for: old)
        forget(old)
        restore(moved, for: new)
    }

    /// Drops entries for files that no longer exist anywhere. Entries for files in
    /// another folder are kept, so switching the screenshot folder back restores them.
    mutating func prune(fileExists: (String) -> Bool) {
        pinned.removeAll { !fileExists($0) }
        unpinned = unpinned.filter { fileExists($0.key) }
    }
}

// MARK: - Disk

private let log = Logger(subsystem: "dev.awln.pluck", category: "ShotIndex")

extension ShotIndex {
    static let defaultURL = URL.applicationSupportDirectory.appending(path: "Pluck/index.json")

    /// Loads the index, or starts fresh. A file that can't be read is set aside
    /// next to it, never silently overwritten.
    static func load(from url: URL) -> ShotIndex {
        guard let data = try? Data(contentsOf: url) else { return ShotIndex() }
        do {
            return try decoder.decode(ShotIndex.self, from: data)
        } catch {
            log.error("Index unreadable, starting fresh: \(error)")
            try? FileManager.default.removeItem(at: url.appendingPathExtension("corrupt"))
            try? FileManager.default.moveItem(at: url, to: url.appendingPathExtension("corrupt"))
            return ShotIndex()
        }
    }

    func save(to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Self.encoder.encode(self).write(to: url, options: .atomic)
    }

    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        return e
    }()

    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()
}
