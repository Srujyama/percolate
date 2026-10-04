import Foundation
import IOKit.ps

/// Watches power source changes and applies the battery-related triggers.
final class BatteryMonitor {
    static let shared = BatteryMonitor()

    private(set) var isOnAC = true
    private(set) var percent: Int?
    private var runLoopSource: CFRunLoopSource?

    var hasInternalBattery: Bool { percent != nil }

    func start() {
        read()
        let ctx = Unmanaged.passUnretained(self).toOpaque()
        guard let src = IOPSNotificationCreateRunLoopSource({ ctx in
            guard let ctx else { return }
            Unmanaged<BatteryMonitor>.fromOpaque(ctx).takeUnretainedValue().powerChanged()
        }, ctx)?.takeRetainedValue() else { return }
        runLoopSource = src
        CFRunLoopAddSource(CFRunLoopGetMain(), src, .defaultMode)
    }

    private func read() {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue() else { return }
        if let type = IOPSGetProvidingPowerSourceType(info)?.takeUnretainedValue() as String? {
            isOnAC = (type == kIOPMACPowerKey)
        }
        percent = nil
        let list = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef] ?? []
        for ps in list {
            guard let desc = IOPSGetPowerSourceDescription(info, ps)?.takeUnretainedValue() as? [String: Any],
                  (desc[kIOPSTypeKey] as? String) == kIOPSInternalBatteryType,
                  let cur = desc[kIOPSCurrentCapacityKey] as? Int,
                  let max = desc[kIOPSMaxCapacityKey] as? Int, max > 0 else { continue }
            percent = cur * 100 / max
        }
    }

    private func powerChanged() {
        let wasOnAC = isOnAC
        let oldPercent = percent
        read()
        let awake = AwakeController.shared

        if !wasOnAC && isOnAC {
            if Prefs.bool(PrefKey.activateOnPowerConnect), !awake.isActive {
                awake.activate(reason: .chargerConnected)
            }
        } else if wasOnAC && !isOnAC {
            if Prefs.bool(PrefKey.deactivateOnPowerDisconnect), awake.isActive {
                awake.deactivate(reason: .chargerDisconnected)
            }
        }

        let threshold = Prefs.lowBatteryThreshold
        if Prefs.bool(PrefKey.deactivateOnLowBattery), !isOnAC, awake.isActive,
           let p = percent, p < threshold, (oldPercent ?? 100) >= threshold || wasOnAC {
            awake.deactivate(reason: .lowBattery)
        }
    }
}
