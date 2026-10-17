import Foundation

/// Calls `onChange` on the main actor whenever an entry in `folder` is added,
/// removed or renamed. A capture landing is a rename, so it's covered.
final class FolderWatcher {
    private let source: any DispatchSourceFileSystemObject

    init?(folder: URL, onChange: @escaping @MainActor () -> Void) {
        let fd = open(folder.path(percentEncoded: false), O_EVTONLY)
        guard fd >= 0 else { return nil }
        source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fd, eventMask: .write, queue: .main)
        source.setEventHandler { MainActor.assumeIsolated { onChange() } }
        source.setCancelHandler { close(fd) }
        source.resume()
    }

    deinit { source.cancel() }
}
