import AppKit
import ImageIO
import UniformTypeIdentifiers
@testable import Pluck

/// A fixed "now" for tests.
let testNow = Date(timeIntervalSinceReferenceDate: 800_000_000)

/// One test's private world: a screenshot folder, a fake Trash, an index file,
/// its own defaults and pasteboard, and a clock the test moves by hand. All of
/// it is deleted when the sandbox goes away.
final class Sandbox {
    let root = FileManager.default.temporaryDirectory.appending(path: "PluckTests-\(UUID().uuidString)")
    var folder: URL { root.appending(path: "Screenshots") }
    var incoming: URL { root.appending(path: "Incoming") }
    var handedOff: URL { root.appending(path: "Handed Off") }
    var trash: URL { root.appending(path: "Trash") }
    var indexURL: URL { root.appending(path: "index.json") }
    let pasteboard = NSPasteboard(name: .init("PluckTests-\(UUID().uuidString)"))
    let preferences: Preferences
    var now = testNow

    private let defaultsName = "PluckTests-\(UUID().uuidString)"

    init() throws {
        try FileManager.default.createDirectory(at: root.appending(path: "Screenshots"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: root.appending(path: "Trash"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: root.appending(path: "Incoming"), withIntermediateDirectories: true)
        preferences = Preferences(defaults: UserDefaults(suiteName: defaultsName)!)
    }

    isolated deinit {
        try? FileManager.default.removeItem(at: root)
        UserDefaults().removePersistentDomain(forName: defaultsName)
        pasteboard.releaseGlobally()
    }

    /// A library over this sandbox. Its Trash is a plain folder, so tests never
    /// touch the real one.
    func library() -> ShotLibrary {
        let trash = self.trash
        return ShotLibrary(folder: folder, preferences: preferences, incoming: incoming, handedOff: handedOff, indexURL: indexURL,
                           now: { [unowned self] in now },
                           moveToTrash: { url in
                               let destination = trash.appending(path: url.lastPathComponent)
                               try FileManager.default.moveItem(at: url, to: destination)
                               return destination
                           },
                           pasteboard: pasteboard)
    }

    /// Writes a small PNG into the screenshot folder, or the holding folder for a
    /// capture still waiting. `tagged` marks it as a screen capture the way macOS does.
    @discardableResult
    func addShot(_ name: String, takenAt date: Date = testNow, tagged: Bool = true, waiting: Bool = false,
                 size: CGSize = CGSize(width: 40, height: 25)) throws -> URL {
        let url = (waiting ? incoming : folder).appending(path: name)
        let context = CGContext(data: nil, width: Int(size.width), height: Int(size.height), bitsPerComponent: 8,
                                bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.setFillColor(CGColor(red: 0.85, green: 0.12, blue: 0.36, alpha: 1))
        context.fill(CGRect(origin: .zero, size: size))
        let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(destination, context.makeImage()!, nil)
        CGImageDestinationFinalize(destination)
        try setCreationDate(date, of: url)
        if tagged { try tag(url) }
        return url
    }

    func tag(_ url: URL) throws {
        let value = try PropertyListSerialization.data(fromPropertyList: true, format: .binary, options: 0)
        let result = value.withUnsafeBytes {
            setxattr(url.path(percentEncoded: false), Shot.screenCaptureTag, $0.baseAddress, value.count, 0, 0)
        }
        if result != 0 { throw CocoaError(.fileWriteUnknown) }
    }

    func setCreationDate(_ date: Date, of url: URL) throws {
        try FileManager.default.setAttributes([.creationDate: date], ofItemAtPath: url.path(percentEncoded: false))
    }

    func path(_ name: String) -> String { folder.appending(path: name).path(percentEncoded: false) }
    func waitingPath(_ name: String) -> String { incoming.appending(path: name).path(percentEncoded: false) }
}

extension ShotLibrary {
    var names: [String] { shots.map(\.url.lastPathComponent) }
    var pinnedNames: [String] { pinnedShots.map(\.url.lastPathComponent) }
}
