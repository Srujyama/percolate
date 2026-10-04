import AppKit

@main
final class AppDelegate: NSObject, NSApplicationDelegate {
    static private(set) weak var shared: AppDelegate?
    private(set) var statusBar: StatusBarController?

    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }

    func applicationWillFinishLaunching(_ notification: Notification) {
        AppDelegate.shared = self
        Prefs.registerDefaults()
        NSAppleEventManager.shared().setEventHandler(
            self, andSelector: #selector(handleURL(_:reply:)),
            forEventClass: AEEventClass(kInternetEventClass), andEventID: AEEventID(kAEGetURL))
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let bar = StatusBarController()
        statusBar = bar
        AwakeController.shared.onChange = { [weak bar] in bar?.refresh() }

        BatteryMonitor.shared.start()
        HotKeyManager.shared.action = { AwakeController.shared.toggle() }
        HotKeyManager.shared.registerFromPrefs()

        if Prefs.bool(PrefKey.activateAtLaunch) {
            AwakeController.shared.activate(reason: nil)
        }
        if Prefs.bool(PrefKey.showWelcomeAtLaunch) {
            WindowManager.shared.showWelcome()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        AwakeController.shared.deactivate(reason: nil)
    }

    /// percolate://toggle · percolate://on?minutes=30 · percolate://off · percolate://settings
    @objc private func handleURL(_ event: NSAppleEventDescriptor, reply: NSAppleEventDescriptor) {
        guard let string = event.paramDescriptor(forKeyword: keyDirectObject)?.stringValue,
              let comps = URLComponents(string: string) else { return }
        let minutes = comps.queryItems?.first { $0.name == "minutes" }?.value.flatMap(Int.init)
        switch comps.host?.lowercased() {
        case "toggle": AwakeController.shared.toggle()
        case "on", "activate": AwakeController.shared.activate(minutes: minutes.map { max(0, $0) })
        case "off", "deactivate": AwakeController.shared.deactivate()
        case "settings": WindowManager.shared.showSettings()
        default: break
        }
    }
}
