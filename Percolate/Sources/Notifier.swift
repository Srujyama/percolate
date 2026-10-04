import AppKit
import UserNotifications

enum Notifier {
    enum Event {
        case activated, deactivated, timerElapsed, chargerConnected, chargerDisconnected, lowBattery

        var body: String {
            switch self {
            case .activated: return "Percolate has been activated"
            case .deactivated: return "Percolate has been deactivated"
            case .timerElapsed: return "Timer has elapsed"
            case .chargerConnected: return "Charger connected — Percolate activated"
            case .chargerDisconnected: return "Charger disconnected — Percolate deactivated"
            case .lowBattery: return "Battery below \(Prefs.lowBatteryThreshold)% — Percolate deactivated"
            }
        }
    }

    static func post(_ event: Event) {
        guard Prefs.bool(PrefKey.allowNotifications) else { return }
        let content = UNMutableNotificationContent()
        content.title = "Percolate"
        content.body = event.body
        let req = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(req)
    }

    /// Asks for permission; if the user has denied it, explains how to fix it and flips the toggle back off.
    static func requestAuthorization() {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard !granted else { return }
            DispatchQueue.main.async {
                Prefs.defaults.set(false, forKey: PrefKey.allowNotifications)
                let alert = NSAlert()
                alert.messageText = "Notifications are turned off"
                alert.informativeText = "Notifications for Percolate are disabled in System Settings. Allow them there and try again."
                alert.addButton(withTitle: "Open System Settings")
                alert.addButton(withTitle: "Okay")
                NSApp.activate(ignoringOtherApps: true)
                if alert.runModal() == .alertFirstButtonReturn,
                   let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension") {
                    NSWorkspace.shared.open(url)
                }
            }
        }
    }
}
