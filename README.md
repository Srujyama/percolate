# Percolate ☕

**A free, open-source alternative to paid keep-awake apps like Caffeinated and Amphetamine.**

Percolate is a tiny macOS menu bar app that keeps your Mac awake. No subscription, no in-app
purchases, no tracking, no account. Every feature is free, and the whole thing is about 900 lines
of Swift you can read in an afternoon.

Click the coffee cup to toggle. Right-click (or ⌃-click) to pick how long.

## Why

Keeping a Mac awake is one system call. It shouldn't cost a subscription. Percolate exists so
there's always a free option that matches the paid ones feature for feature. If it pushes them
to get better or cheaper, good. Everyone wins.

## Install

1. Download `Percolate.zip` from the [latest release](https://github.com/srujyama/percolate/releases/latest)
   and unzip it.
2. Drag `Percolate.app` into `/Applications`.
3. Percolate isn't notarized by Apple yet, so macOS will say it "can't be opened" or "is damaged".
   That's Gatekeeper reacting to an unsigned download, not a problem with the app. Fix it once
   with:

   ```sh
   xattr -dr com.apple.quarantine /Applications/Percolate.app
   ```

   Or: try to open it, then go to **System Settings → Privacy & Security** and click **Open Anyway**.

Don't want to trust a binary? [Build it yourself](#build). It takes about a minute.

## Features

- **One-click toggle** from the menu bar. The cup fills while Percolate is active.
- **Durations:** indefinitely, 5/10/15/30 min, 1/2/5 h, or a custom slider (5 min – 12 h).
  The menu shows *"Active until 3:45 PM"* while a timer is running.
- **Allow Display Sleep:** keep the Mac running (downloads, builds) but let the screen turn off.
- **Battery triggers** (laptops): activate when the charger connects, deactivate when it
  disconnects, deactivate when the battery drops below 20%.
- **Global keyboard shortcut** to toggle from anywhere. No Accessibility permission needed.
- **Launch at Login** and **Activate at Launch**.
- **Notifications** on activate, deactivate, timer end and battery events (optional).
- **Colored menu bar icon** (optional).
- **Shortcuts app / Siri:** *Toggle*, *Activate* (with optional minutes) and *Deactivate* actions.
- **AppleScript:**
  ```applescript
  tell application "Percolate" to toggle
  tell application "Percolate" to turn on for 30   -- minutes; 0 = indefinitely
  tell application "Percolate" to turn off
  tell application "Percolate" to is active
  ```
- **URL scheme:** `open "percolate://on?minutes=30"`, `percolate://off`, `percolate://toggle`,
  `percolate://settings`

## How it works

Percolate holds an IOKit power assertion (`IOPMAssertionCreateWithName`):
`PreventUserIdleDisplaySleep` normally, or `PreventUserIdleSystemSleep` when "Allow Display
Sleep" is on. It's the same mechanism as the built-in `caffeinate` command. You can see it in
`pmset -g assertions`. Quitting the app releases the assertion.

## Build

Requires macOS 13+, Xcode 15+ and [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```sh
brew install xcodegen
./build.sh                 # → build/Percolate.app
open build/Percolate.app
```

Run `xcodegen generate` to open the project in Xcode instead. The app icon is drawn by
`swift scripts/make-icon.swift`.

## Layout

| File | Role |
|---|---|
| `AwakeController.swift` | power assertion and duration timer |
| `StatusBarController.swift` | menu bar icon, click handling, menu and custom slider |
| `BatteryMonitor.swift` | power-source notifications and battery triggers |
| `HotKey.swift` | Carbon global hotkey and shortcut recorder |
| `Notifier.swift` | user notifications |
| `Intents.swift` | Shortcuts / App Intents |
| `Scripting.swift` + `Percolate.sdef` | AppleScript |
| `Windows.swift` | Settings, Welcome and About windows (SwiftUI) |

## Releasing

Push a tag (`git tag v1.0.0 && git push --tags`) and the GitHub Actions workflow builds the app
and attaches `Percolate.zip` to a new release.

## Contributing

Issues and pull requests are welcome. Missing a feature from a paid app? Open an issue.

## License

MIT. See [LICENSE](LICENSE).

Percolate is an independent project and isn't affiliated with Caffeinated, Amphetamine or their
developers. Those names belong to their owners.
