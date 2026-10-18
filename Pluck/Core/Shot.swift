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
    /// Where on screen a selection was captured, in global display coordinates
    /// (top-left origin). Nil for whole-display captures, which macOS doesn't tag.
    var captureRect: CGRect? = nil

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
        let rect = (Shot.attribute(Shot.captureRectTag, of: url) as? [Double]).flatMap { r in
            r.count == 4 ? CGRect(x: r[0], y: r[1], width: r[2], height: r[3]) : nil
        }
        self.init(url: url, capturedAt: capturedAt, pixelSize: CGSize(width: width, height: height),
                  fileID: values.fileIdentifier, captureRect: rect)
    }

    /// True only for images macOS tagged as screen captures. The tag is an extended
    /// attribute, so it survives renames and doesn't depend on Spotlight.
    static func isScreenshot(_ url: URL) -> Bool {
        guard UTType(filenameExtension: url.pathExtension)?.conforms(to: .image) == true else { return false }
        return attribute(screenCaptureTag, of: url) as? Bool == true
    }

    static let screenCaptureTag = "com.apple.metadata:kMDItemIsScreenCapture"
    static let captureRectTag = "com.apple.metadata:kMDItemScreenCaptureGlobalRect"

    /// A metadata attribute macOS stores on the file, as a property list value.
    private static func attribute(_ name: String, of url: URL) -> Any? {
        let path = url.path(percentEncoded: false)
        let size = getxattr(path, name, nil, 0, 0, 0)
        guard size > 0 else { return nil }
        var data = Data(count: size)
        let read = data.withUnsafeMutableBytes { getxattr(path, name, $0.baseAddress, size, 0, 0) }
        guard read == size else { return nil }
        return try? PropertyListSerialization.propertyList(from: data, format: nil)
    }
}
