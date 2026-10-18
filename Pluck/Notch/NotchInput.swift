import AppKit

/// What macOS says about the pointer, clicks in other apps, keys and menus. No
/// one source sees every pointer move, so three are combined; see Platform facts.
final class NotchInput {
    /// A position in screen coordinates, and whether the pointer is moving faster
    /// than `Timing.passingSpeed`. Not called while a menu is open: the pointer is
    /// on the menu then, and the notch should stay as it is.
    var pointerMoved: (CGPoint, _ fast: Bool) -> Void = { _, _ in }
    var clickedInAnotherApp: () -> Void = {}
    /// True keeps the key from the rest of the app, whose menus would take ⌘C.
    var keyDown: (NSEvent) -> Bool = { _ in false }
    /// Sampling is the backstop for moves the monitor misses: often while the notch
    /// is open, rarely at rest.
    var sampleInterval: () -> TimeInterval = { Theme.Timing.pointerAtRest }

    private var monitors: [Any] = []
    private var sampler: Task<Void, Never>?
    private var last: (point: CGPoint, time: TimeInterval)?
    private var openMenus = 0

    init() {
        let moved = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { [weak self] event in
            let point = Self.screenLocation(of: event)
            MainActor.assumeIsolated { self?.report(point) }
        }
        let clicked = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            MainActor.assumeIsolated { self?.clickedInAnotherApp() }
        }
        let keys = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            let handled = MainActor.assumeIsolated { self?.keyDown(event) ?? false }
            return handled ? nil : event
        }
        monitors = [moved, clicked, keys].compactMap { $0 }

        // Handled as posted, so a menu's end is never handled before its begin.
        for (name, change) in [(NSMenu.didBeginTrackingNotification, 1), (NSMenu.didEndTrackingNotification, -1)] {
            _ = NotificationCenter.default.addObserver(forName: name, object: nil, queue: nil) { [weak self] _ in
                MainActor.assumeIsolated {
                    guard let self else { return }
                    self.openMenus = max(0, self.openMenus + change)
                    if self.openMenus == 0 { self.report(NSEvent.mouseLocation) }
                }
            }
        }

        // ponytail: sampling; an event tap would be event-driven, but needs Input Monitoring.
        sampler = Task { [weak self] in
            var sampled: CGPoint?
            while let self {
                let point = NSEvent.mouseLocation
                if point != sampled {
                    sampled = point
                    report(point)
                }
                let interval = sampleInterval()
                try? await Task.sleep(for: .seconds(interval), tolerance: .seconds(interval / 4))
            }
        }
    }

    /// A pointer position from any source: the monitors, the notch's own hover, a drag.
    func report(_ point: CGPoint) {
        guard openMenus == 0 else { return }
        pointerMoved(point, isFast(point))
    }

    private func isFast(_ point: CGPoint) -> Bool {
        let now = ProcessInfo.processInfo.systemUptime
        // Sources report the same move moments apart, too close to measure.
        guard let last, now - last.time >= 1.0 / 120 else {
            if last == nil { last = (point, now) }
            return false
        }
        self.last = (point, now)
        return hypot(point.x - last.point.x, point.y - last.point.y) / (now - last.time) > Theme.Timing.passingSpeed
    }

    /// Not `locationInWindow`: a global event can still name one of Pluck's
    /// windows, and then it's in that window's coordinates. Quartz's location is
    /// always global, top down from the primary display.
    private static func screenLocation(of event: NSEvent) -> CGPoint {
        guard let point = event.cgEvent?.location, let primary = NSScreen.screens.first else { return NSEvent.mouseLocation }
        return CGPoint(x: point.x, y: primary.frame.maxY - point.y)
    }
}
