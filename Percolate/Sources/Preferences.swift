import Foundation

/// All persisted settings. Views bind to these keys with `@AppStorage`;
/// non-UI code reads them through `Prefs`.
enum PrefKey {
    static let selectedMinutes = "selectedMinutes"          // 0 = indefinitely
    static let customMinutes = "customMinutes"
    static let allowDisplaySleep = "allowDisplaySleep"
    static let activateAtLaunch = "activateAtLaunch"
    static let activateWithLeftClick = "activateWithLeftClick"
    static let coloredIcon = "coloredIcon"
    static let activateOnPowerConnect = "activateOnPowerConnect"
    static let deactivateOnPowerDisconnect = "deactivateOnPowerDisconnect"
    static let deactivateOnLowBattery = "deactivateOnLowBattery"
    static let allowNotifications = "allowNotifications"
    static let showWelcomeAtLaunch = "showWelcomeAtLaunch"
    static let hotKeyCode = "hotKeyCode"
    static let hotKeyModifiers = "hotKeyModifiers"
    static let hotKeyDisplay = "hotKeyDisplay"
}

enum Prefs {
    static let defaults = UserDefaults.standard

    static let presetMinutes = [0, 5, 10, 15, 30, 60, 120, 300]
    static let customRange = 5.0...720.0
    static let customStep = 5.0
    static let lowBatteryThreshold = 20

    static func registerDefaults() {
        defaults.register(defaults: [
            PrefKey.selectedMinutes: 0,
            PrefKey.customMinutes: 45,
            PrefKey.allowDisplaySleep: false,
            PrefKey.activateAtLaunch: false,
            PrefKey.activateWithLeftClick: true,
            PrefKey.coloredIcon: false,
            PrefKey.activateOnPowerConnect: false,
            PrefKey.deactivateOnPowerDisconnect: false,
            PrefKey.deactivateOnLowBattery: true,
            PrefKey.allowNotifications: false,
            PrefKey.showWelcomeAtLaunch: true,
            PrefKey.hotKeyCode: -1,
        ])
    }

    static var selectedMinutes: Int {
        get { defaults.integer(forKey: PrefKey.selectedMinutes) }
        set { defaults.set(newValue, forKey: PrefKey.selectedMinutes) }
    }
    static var customMinutes: Int {
        get { defaults.integer(forKey: PrefKey.customMinutes) }
        set { defaults.set(newValue, forKey: PrefKey.customMinutes) }
    }
    static func bool(_ key: String) -> Bool { defaults.bool(forKey: key) }
}

enum DurationFormat {
    static func label(minutes: Int) -> String {
        if minutes == 0 { return "Indefinitely" }
        let f = DateComponentsFormatter()
        f.allowedUnits = [.hour, .minute]
        f.unitsStyle = .full
        return f.string(from: TimeInterval(minutes * 60)) ?? "\(minutes) min"
    }

    static func short(minutes: Int) -> String {
        let f = DateComponentsFormatter()
        f.allowedUnits = [.hour, .minute]
        f.unitsStyle = .abbreviated
        return f.string(from: TimeInterval(minutes * 60)) ?? "\(minutes)m"
    }

    static func until(_ date: Date) -> String {
        let f = DateFormatter()
        f.timeStyle = .short
        f.dateStyle = Calendar.current.isDateInToday(date) ? .none : .short
        return f.string(from: date)
    }
}
