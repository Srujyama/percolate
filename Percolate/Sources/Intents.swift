import AppIntents

struct TogglePercolateIntent: AppIntent {
    static var title: LocalizedStringResource = "Toggle Percolate"
    static var description = IntentDescription("Toggles whether Percolate keeps your Mac awake.")

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<Bool> {
        AwakeController.shared.toggle()
        return .result(value: AwakeController.shared.isActive)
    }
}

struct ActivatePercolateIntent: AppIntent {
    static var title: LocalizedStringResource = "Activate Percolate"
    static var description = IntentDescription("Keeps your Mac awake, optionally for a number of minutes (0 = indefinitely).")

    @Parameter(title: "Minutes", description: "Leave empty to use the duration selected in the menu.")
    var minutes: Int?

    @MainActor
    func perform() async throws -> some IntentResult {
        AwakeController.shared.activate(minutes: minutes.map { max(0, $0) })
        return .result()
    }
}

struct DeactivatePercolateIntent: AppIntent {
    static var title: LocalizedStringResource = "Deactivate Percolate"
    static var description = IntentDescription("Lets your Mac sleep normally again.")

    @MainActor
    func perform() async throws -> some IntentResult {
        AwakeController.shared.deactivate()
        return .result()
    }
}

struct PercolateShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: TogglePercolateIntent(), phrases: ["Toggle \(.applicationName)"],
                    shortTitle: "Toggle", systemImageName: "cup.and.saucer")
        AppShortcut(intent: ActivatePercolateIntent(), phrases: ["Activate \(.applicationName)"],
                    shortTitle: "Activate", systemImageName: "cup.and.saucer.fill")
        AppShortcut(intent: DeactivatePercolateIntent(), phrases: ["Deactivate \(.applicationName)"],
                    shortTitle: "Deactivate", systemImageName: "moon.zzz")
    }
}
