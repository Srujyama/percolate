import AppKit
import Carbon.HIToolbox
import SwiftUI

/// A single global shortcut registered through Carbon (works without Accessibility permission).
final class HotKeyManager {
    static let shared = HotKeyManager()

    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?
    var action: (() -> Void)?

    func registerFromPrefs() {
        unregister()
        let code = Prefs.defaults.integer(forKey: PrefKey.hotKeyCode)
        guard code >= 0 else { return }
        let mods = UInt32(Prefs.defaults.integer(forKey: PrefKey.hotKeyModifiers))
        installHandlerIfNeeded()
        let id = EventHotKeyID(signature: OSType(0x5043_4C54), id: 1) // 'PCLT'
        let status = RegisterEventHotKey(UInt32(code), mods, id, GetApplicationEventTarget(), 0, &hotKeyRef)
        if status != noErr { NSLog("Percolate: RegisterEventHotKey failed: \(status)") }
    }

    func unregister() {
        if let ref = hotKeyRef { UnregisterEventHotKey(ref) }
        hotKeyRef = nil
    }

    private func installHandlerIfNeeded() {
        guard handlerRef == nil else { return }
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, _ in
            DispatchQueue.main.async { HotKeyManager.shared.action?() }
            return noErr
        }, 1, &spec, nil, &handlerRef)
    }

    static func carbonModifiers(_ flags: NSEvent.ModifierFlags) -> Int {
        var m = 0
        if flags.contains(.command) { m |= cmdKey }
        if flags.contains(.option) { m |= optionKey }
        if flags.contains(.control) { m |= controlKey }
        if flags.contains(.shift) { m |= shiftKey }
        return m
    }

    static func display(flags: NSEvent.ModifierFlags, event: NSEvent) -> String {
        var s = ""
        if flags.contains(.control) { s += "⌃" }
        if flags.contains(.option) { s += "⌥" }
        if flags.contains(.shift) { s += "⇧" }
        if flags.contains(.command) { s += "⌘" }
        let special: [Int: String] = [
            kVK_Space: "Space", kVK_Return: "↩", kVK_Tab: "⇥", kVK_Delete: "⌫", kVK_ForwardDelete: "⌦",
            kVK_LeftArrow: "←", kVK_RightArrow: "→", kVK_UpArrow: "↑", kVK_DownArrow: "↓",
            kVK_F1: "F1", kVK_F2: "F2", kVK_F3: "F3", kVK_F4: "F4", kVK_F5: "F5", kVK_F6: "F6",
            kVK_F7: "F7", kVK_F8: "F8", kVK_F9: "F9", kVK_F10: "F10", kVK_F11: "F11", kVK_F12: "F12",
        ]
        s += special[Int(event.keyCode)] ?? (event.charactersIgnoringModifiers ?? "?").uppercased()
        return s
    }
}

/// Click to record, press a shortcut (must include ⌘, ⌥ or ⌃), Esc to cancel, ⌫ to clear.
final class ShortcutRecorderButton: NSButton {
    var onChange: (() -> Void)?
    private var recording = false { didSet { refreshTitle() } }
    private var monitor: Any?

    override init(frame: NSRect) {
        super.init(frame: frame)
        bezelStyle = .rounded
        target = self
        action = #selector(clicked)
        refreshTitle()
    }
    required init?(coder: NSCoder) { fatalError() }

    func refreshTitle() {
        if recording { title = "Type shortcut…"; return }
        let current = Prefs.defaults.string(forKey: PrefKey.hotKeyDisplay) ?? ""
        title = Prefs.defaults.integer(forKey: PrefKey.hotKeyCode) >= 0 && !current.isEmpty ? current : "Record Shortcut"
    }

    @objc private func clicked() {
        recording ? stop() : start()
    }

    private func start() {
        recording = true
        HotKeyManager.shared.unregister()
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handle(event)
            return nil
        }
    }

    private func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        recording = false
        HotKeyManager.shared.registerFromPrefs()
    }

    private func handle(_ event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        switch Int(event.keyCode) {
        case kVK_Escape:
            stop(); return
        case kVK_Delete where flags.intersection([.command, .option, .control]).isEmpty:
            Prefs.defaults.set(-1, forKey: PrefKey.hotKeyCode)
            Prefs.defaults.removeObject(forKey: PrefKey.hotKeyDisplay)
            stop(); onChange?(); return
        default: break
        }
        guard !flags.intersection([.command, .option, .control]).isEmpty else { NSSound.beep(); return }
        Prefs.defaults.set(Int(event.keyCode), forKey: PrefKey.hotKeyCode)
        Prefs.defaults.set(HotKeyManager.carbonModifiers(flags), forKey: PrefKey.hotKeyModifiers)
        Prefs.defaults.set(HotKeyManager.display(flags: flags, event: event), forKey: PrefKey.hotKeyDisplay)
        stop()
        onChange?()
    }
}

struct ShortcutRecorder: NSViewRepresentable {
    func makeNSView(context: Context) -> ShortcutRecorderButton { ShortcutRecorderButton(frame: .zero) }
    func updateNSView(_ view: ShortcutRecorderButton, context: Context) { view.refreshTitle() }
}
