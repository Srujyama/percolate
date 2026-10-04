import AppKit
import SwiftUI

final class WindowManager {
    static let shared = WindowManager()
    private var windows: [String: NSWindow] = [:]

    func showSettings() { show("settings", title: "Percolate Settings", view: SettingsView()) }
    func showWelcome() { show("welcome", title: "Welcome to Percolate", view: WelcomeView()) }
    func showAbout() { show("about", title: "About Percolate", view: AboutView()) }

    private func show<V: View>(_ key: String, title: String, view: V) {
        if windows[key] == nil {
            let w = NSWindow(contentViewController: NSHostingController(rootView: view))
            w.title = title
            w.styleMask = [.titled, .closable]
            w.isReleasedWhenClosed = false
            w.center()
            windows[key] = w
        }
        NSApp.activate(ignoringOtherApps: true)
        windows[key]?.makeKeyAndOrderFront(nil)
    }

    func close(_ key: String) { windows[key]?.close() }
}

struct SettingsView: View {
    @AppStorage(PrefKey.activateAtLaunch) private var activateAtLaunch = false
    @AppStorage(PrefKey.activateWithLeftClick) private var leftClick = true
    @AppStorage(PrefKey.allowDisplaySleep) private var allowDisplaySleep = false
    @AppStorage(PrefKey.coloredIcon) private var coloredIcon = false
    @AppStorage(PrefKey.activateOnPowerConnect) private var onConnect = false
    @AppStorage(PrefKey.deactivateOnPowerDisconnect) private var onDisconnect = false
    @AppStorage(PrefKey.deactivateOnLowBattery) private var lowBattery = true
    @AppStorage(PrefKey.allowNotifications) private var notifications = false
    @State private var launchAtLogin = LoginItem.isEnabled

    var body: some View {
        Form {
            Section("General") {
                Toggle("Launch at Login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { LoginItem.set($0) }
                Toggle("Activate at Launch", isOn: $activateAtLaunch)
                Toggle("Activate with Left Click", isOn: $leftClick)
                    .help("Left-click the cup to toggle; right-click (or ⌃-click) for the menu.")
                Toggle("Allow Display Sleep", isOn: $allowDisplaySleep)
                    .help("Keep the Mac awake but let the screen turn off.")
                    .onChange(of: allowDisplaySleep) { _ in AwakeController.shared.refreshAssertionType() }
                Toggle("Colored Menu Bar Icon", isOn: $coloredIcon)
                    .onChange(of: coloredIcon) { _ in AppDelegate.shared?.statusBar?.refresh() }
                LabeledContent("Keyboard Shortcut") {
                    ShortcutRecorder().frame(width: 150)
                }
            }
            if BatteryMonitor.shared.hasInternalBattery {
                Section("Battery") {
                    Toggle("Activate on Power Connect", isOn: $onConnect)
                    Toggle("Deactivate on Power Disconnect", isOn: $onDisconnect)
                    Toggle("Deactivate When Below \(Prefs.lowBatteryThreshold)%", isOn: $lowBattery)
                }
            }
            Section("Notifications") {
                Toggle("Allow Notifications", isOn: $notifications)
                    .onChange(of: notifications) { if $0 { Notifier.requestAuthorization() } }
            }
        }
        .formStyle(.grouped)
        .frame(width: 400)
        .fixedSize()
    }
}

struct WelcomeView: View {
    @AppStorage(PrefKey.showWelcomeAtLaunch) private var showAtLaunch = true

    var body: some View {
        VStack(spacing: 16) {
            Image(nsImage: NSApp.applicationIconImage).resizable().frame(width: 96, height: 96)
            Text("Welcome to Percolate").font(.title.bold())
            Text("Percolate keeps your Mac awake. Find it behind the coffee cup in your menu bar — click it to toggle, right-click for durations and settings.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Toggle("Show this window at launch", isOn: $showAtLaunch)
            HStack {
                Button("Settings…") { WindowManager.shared.showSettings() }
                Button("Okay") { WindowManager.shared.close("welcome") }.keyboardShortcut(.defaultAction)
            }
        }
        .padding(28)
        .frame(width: 380)
    }
}

struct AboutView: View {
    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
    }

    var body: some View {
        VStack(spacing: 10) {
            Image(nsImage: NSApp.applicationIconImage).resizable().frame(width: 80, height: 80)
            Text("Percolate").font(.title2.bold())
            Text("Version \(version)").foregroundStyle(.secondary)
            Text("A free, open-source app that keeps your Mac awake.")
                .multilineTextAlignment(.center)
            Text("MIT License").font(.caption).foregroundStyle(.secondary)
        }
        .padding(28)
        .frame(width: 320)
    }
}
