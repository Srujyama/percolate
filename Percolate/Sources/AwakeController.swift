import Foundation
import IOKit.pwr_mgt

/// Owns the power assertion that keeps the Mac awake, plus the optional timer.
final class AwakeController: ObservableObject {
    static let shared = AwakeController()

    @Published private(set) var isActive = false
    @Published private(set) var endDate: Date?

    private var assertionID: IOPMAssertionID = 0
    private var timer: Timer?

    var onChange: (() -> Void)?

    /// Activate for `minutes` (nil = the user's selected duration, 0 = indefinitely).
    func activate(minutes: Int? = nil, reason: Notifier.Event? = .activated) {
        let minutes = minutes ?? Prefs.selectedMinutes
        guard createAssertion() else { return }
        timer?.invalidate()
        timer = nil
        endDate = nil
        if minutes > 0 {
            let end = Date().addingTimeInterval(TimeInterval(minutes * 60))
            endDate = end
            let t = Timer(fire: end, interval: 0, repeats: false) { [weak self] _ in
                self?.deactivate(reason: .timerElapsed)
            }
            RunLoop.main.add(t, forMode: .common)
            timer = t
        }
        let wasActive = isActive
        isActive = true
        onChange?()
        if !wasActive, let reason { Notifier.post(reason) }
    }

    func deactivate(reason: Notifier.Event? = .deactivated) {
        timer?.invalidate()
        timer = nil
        endDate = nil
        releaseAssertion()
        let wasActive = isActive
        isActive = false
        onChange?()
        if wasActive, let reason { Notifier.post(reason) }
    }

    func toggle() {
        isActive ? deactivate() : activate()
    }

    /// Re-create the assertion after "Allow Display Sleep" changes, keeping the timer.
    func refreshAssertionType() {
        guard isActive else { return }
        _ = createAssertion()
    }

    @discardableResult
    private func createAssertion() -> Bool {
        let type = Prefs.bool(PrefKey.allowDisplaySleep)
            ? kIOPMAssertionTypePreventUserIdleSystemSleep
            : kIOPMAssertionTypePreventUserIdleDisplaySleep
        var newID: IOPMAssertionID = 0
        let result = IOPMAssertionCreateWithName(
            type as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            "Percolate is keeping your Mac awake" as CFString,
            &newID)
        guard result == kIOReturnSuccess else {
            NSLog("Percolate: IOPMAssertionCreateWithName failed: \(result)")
            return false
        }
        releaseAssertion()
        assertionID = newID
        return true
    }

    private func releaseAssertion() {
        if assertionID != 0 {
            IOPMAssertionRelease(assertionID)
            assertionID = 0
        }
    }
}
