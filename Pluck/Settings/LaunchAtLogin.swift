import OSLog
import ServiceManagement

private let log = Logger(subsystem: "app.pluck.Pluck", category: "LaunchAtLogin")

/// "Open Pluck at login". The system owns it, so it's read from there each time
/// and never stored in Pluck's preferences.
enum LaunchAtLogin {
    static var isEnabled: Bool { SMAppService.mainApp.status == .enabled }

    /// Registered, but the user still has to allow it in System Settings.
    static var needsApproval: Bool { SMAppService.mainApp.status == .requiresApproval }

    static func set(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        } catch {
            log.error("Couldn't \(enabled ? "register" : "unregister", privacy: .public) the login item: \(error)")
        }
    }

    static func openSystemSettings() { SMAppService.openSystemSettingsLoginItems() }
}
