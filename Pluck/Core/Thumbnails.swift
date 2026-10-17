import Foundation
import ImageIO

/// Small, cached versions of shots for the notch to draw. Decoding happens off
/// the main thread; the cache drops old entries on its own under memory pressure.
enum Thumbnails {
    /// Long edge in pixels: sharp at 2x for the largest tile and the Preview.
    private static let maxPixelSize = 600
    // ponytail: one size for every tile; add a small size if memory ever shows up in profiles.
    private static let cache: NSCache<NSString, CGImage> = {
        let cache = NSCache<NSString, CGImage>()
        cache.totalCostLimit = 64 * 1024 * 1024
        return cache
    }()

    /// The cached thumbnail, if there is one. Lets views draw it on their first frame.
    static func cached(_ shot: Shot) -> CGImage? {
        cache.object(forKey: key(shot))
    }

    static func image(for shot: Shot) async -> CGImage? {
        if let image = cached(shot) { return image }
        guard let image = await decode(shot.url, maxPixelSize: maxPixelSize) else { return nil }
        cache.setObject(image, forKey: key(shot), cost: image.bytesPerRow * image.height)
        return image
    }

    /// Decodes ahead of time, so Peek and the Preview open with images in place.
    static func prefetch(_ shots: some Sequence<Shot>) {
        for shot in shots where cached(shot) == nil {
            Task { _ = await image(for: shot) }
        }
    }

    /// Keyed by path and capture time, so a file replaced under the same name
    /// gets a fresh thumbnail.
    private static func key(_ shot: Shot) -> NSString {
        "\(shot.id)|\(shot.capturedAt.timeIntervalSinceReferenceDate)" as NSString
    }

    @concurrent
    private static func decode(_ url: URL, maxPixelSize: Int) async -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }
}
