import Foundation
import ImageIO
import UniformTypeIdentifiers

/// A screenshot Pluck manages. Everything here is read from the file, which stays
/// the source of truth; what Pluck adds on top (pins, drag-outs) is in `ShotIndex`.
struct Shot: Identifiable, Equatable {
    let url: URL
    let capturedAt: Date
    let pixelSize: CGSize
    /// The file system's ID for the file. It survives renames, which is how a shot
    /// keeps its pin when the user renames it in Finder.
    let fileID: UInt64?

    /// The file's path: unique within the folder, and readable in the index file.
    var id: String { url.path(percentEncoded: false) }

    static func newestFirst(_ a: Shot, _ b: Shot) -> Bool {
        (a.capturedAt, a.id) > (b.capturedAt, b.id)
    }
}

extension Shot {
    /// Reads a shot from disk, or returns nil if the file isn't a screenshot image.
    // ponytail: reads the image header, which downloads an evicted iCloud Desktop file; read size lazily if that shows up.
    init?(screenshotAt url: URL) {
        guard Shot.isScreenshot(url),
              let values = try? url.resourceValues(forKeys: [.creationDateKey, .fileIdentifierKey]),
              let capturedAt = values.creationDate,
              let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int
        else { return nil }
        self.init(url: url, capturedAt: capturedAt, pixelSize: CGSize(width: width, height: height), fileID: values.fileIdentifier)
    }

    /// True only for images macOS tagged as screen captures. The tag is an extended
    /// attribute, so it survives renames and doesn't depend on Spotlight.
    static func isScreenshot(_ url: URL) -> Bool {
        guard UTType(filenameExtension: url.pathExtension)?.conforms(to: .image) == true else { return false }
        let path = url.path(percentEncoded: false)
        let size = getxattr(path, screenCaptureTag, nil, 0, 0, 0)
        guard size > 0 else { return false }
        var data = Data(count: size)
        let read = data.withUnsafeMutableBytes { getxattr(path, screenCaptureTag, $0.baseAddress, size, 0, 0) }
        guard read == size else { return false }
        return (try? PropertyListSerialization.propertyList(from: data, format: nil)) as? Bool == true
    }

    static let screenCaptureTag = "com.apple.metadata:kMDItemIsScreenCapture"
}
