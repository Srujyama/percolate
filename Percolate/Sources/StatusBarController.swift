import AppKit

final class StatusBarController: NSObject, NSMenuDelegate {
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let awake = AwakeController.shared
    private var countdownTimer: Timer?

    override init() {
        super.init()
        if let button = item.button {
            button.target = self
            button.action = #selector(clicked)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        refresh()
    }

    // MARK: Icon

    func refresh() {
        guard let button = item.button else { return }
        let name = awake.isActive ? "cup.and.saucer.fill" : "cup.and.saucer"
        let image = NSImage(systemSymbolName: name, accessibilityDescription: "Percolate")
        let colored = awake.isActive && Prefs.bool(PrefKey.coloredIcon)
        image?.isTemplate = !colored
        button.image = image
        button.contentTintColor = colored ? .systemBrown : nil
        button.appearsDisabled = false
        button.toolTip = statusLine
    }

    private var statusLine: String {
        guard awake.isActive else { return "Percolate is off" }
        if let end = awake.endDate { return "Active until \(DurationFormat.until(end))" }
        return "Active indefinitely"
    }

    // MARK: Clicks

    @objc private func clicked() {
        let event = NSApp.currentEvent
        let isRight = event?.type == .rightMouseUp || event?.modifierFlags.contains(.control) == true
        if Prefs.bool(PrefKey.activateWithLeftClick) && !isRight {
            awake.toggle()
        } else {
            showMenu()
        }
    }

    private func showMenu() {
        item.menu = buildMenu()
        item.button?.performClick(nil)
        item.menu = nil
    }

    // MARK: Menu

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()
        menu.delegate = self
        menu.autoenablesItems = false

        let status = NSMenuItem(title: statusLine, action: nil, keyEquivalent: "")
        status.isEnabled = false
        menu.addItem(status)

        let toggle = NSMenuItem(title: awake.isActive ? "Deactivate" : "Activate",
                                action: #selector(toggleFromMenu), keyEquivalent: "")
        toggle.target = self
        menu.addItem(toggle)
        menu.addItem(.separator())

        let header = NSMenuItem(title: "Duration", action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)
        let selected = Prefs.selectedMinutes
        let isCustom = !Prefs.presetMinutes.contains(selected)
        for minutes in Prefs.presetMinutes {
            let mi = NSMenuItem(title: DurationFormat.label(minutes: minutes), action: #selector(pickDuration(_:)), keyEquivalent: "")
            mi.target = self
            mi.tag = minutes
            mi.state = (!isCustom && minutes == selected) ? .on : .off
            mi.indentationLevel = 1
            menu.addItem(mi)
        }
        let custom = NSMenuItem(title: "Custom (\(DurationFormat.short(minutes: Prefs.customMinutes)))",
                                action: #selector(pickCustom), keyEquivalent: "")
        custom.target = self
        custom.state = isCustom ? .on : .off
        custom.indentationLevel = 1
        menu.addItem(custom)
        let sliderItem = NSMenuItem()
        sliderItem.view = CustomDurationSliderView { [weak custom] minutes, finished in
            custom?.title = "Custom (\(DurationFormat.short(minutes: minutes)))"
            if finished {
                Prefs.customMinutes = minutes
                Prefs.selectedMinutes = minutes
                AwakeController.shared.activate(minutes: minutes)
            }
        }
        menu.addItem(sliderItem)

        menu.addItem(.separator())
        let settings = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)
        let about = NSMenuItem(title: "About Percolate", action: #selector(openAbout), keyEquivalent: "")
        about.target = self
        menu.addItem(about)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit Percolate", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        return menu
    }

    /// Keep the "Active until…" line live while the menu is open.
    func menuWillOpen(_ menu: NSMenu) {
        let t = Timer(timeInterval: 1, repeats: true) { [weak self, weak menu] _ in
            guard let self, let first = menu?.items.first else { return }
            first.title = self.statusLine
        }
        RunLoop.main.add(t, forMode: .common)
        countdownTimer = t
    }

    func menuDidClose(_ menu: NSMenu) {
        countdownTimer?.invalidate()
        countdownTimer = nil
    }

    @objc private func toggleFromMenu() { awake.toggle() }

    @objc private func pickDuration(_ sender: NSMenuItem) {
        Prefs.selectedMinutes = sender.tag
        awake.activate(minutes: sender.tag)
    }

    @objc private func pickCustom() {
        Prefs.selectedMinutes = Prefs.customMinutes
        awake.activate(minutes: Prefs.customMinutes)
    }

    @objc private func openSettings() { WindowManager.shared.showSettings() }
    @objc private func openAbout() { WindowManager.shared.showAbout() }
}

/// A slider embedded in the menu for picking a custom duration.
final class CustomDurationSliderView: NSView {
    private let slider = NSSlider()
    private let label = NSTextField(labelWithString: "")
    private let onChange: (Int, Bool) -> Void

    init(onChange: @escaping (Int, Bool) -> Void) {
        self.onChange = onChange
        super.init(frame: NSRect(x: 0, y: 0, width: 240, height: 30))
        slider.minValue = Prefs.customRange.lowerBound
        slider.maxValue = Prefs.customRange.upperBound
        slider.doubleValue = Double(Prefs.customMinutes)
        slider.isContinuous = true
        slider.controlSize = .small
        slider.target = self
        slider.action = #selector(changed)
        label.font = .monospacedDigitSystemFont(ofSize: NSFont.smallSystemFontSize, weight: .regular)
        label.textColor = .secondaryLabelColor
        label.alignment = .right
        for v in [slider, label] as [NSView] {
            v.translatesAutoresizingMaskIntoConstraints = false
            addSubview(v)
        }
        NSLayoutConstraint.activate([
            slider.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 34),
            slider.centerYAnchor.constraint(equalTo: centerYAnchor),
            label.leadingAnchor.constraint(equalTo: slider.trailingAnchor, constant: 8),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
            label.widthAnchor.constraint(equalToConstant: 52),
        ])
        updateLabel()
    }
    required init?(coder: NSCoder) { fatalError() }

    private var minutes: Int {
        Int((slider.doubleValue / Prefs.customStep).rounded() * Prefs.customStep)
    }

    private func updateLabel() { label.stringValue = DurationFormat.short(minutes: minutes) }

    @objc private func changed() {
        updateLabel()
        let finished = NSApp.currentEvent?.type == .leftMouseUp
        onChange(minutes, finished)
        if finished { enclosingMenuItem?.menu?.cancelTracking() }
    }
}
