import Foundation

// AppleScript commands declared in Percolate.sdef.
//   tell application "Percolate" to toggle
//   tell application "Percolate" to turn on for 30
//   tell application "Percolate" to turn off
//   tell application "Percolate" to is active

@objc(PercolateToggleCommand)
final class ToggleCommand: NSScriptCommand {
    override func performDefaultImplementation() -> Any? {
        AwakeController.shared.toggle()
        return AwakeController.shared.isActive
    }
}

@objc(PercolateTurnOnCommand)
final class TurnOnCommand: NSScriptCommand {
    override func performDefaultImplementation() -> Any? {
        let minutes = (evaluatedArguments?["minutes"] as? NSNumber)?.intValue
        AwakeController.shared.activate(minutes: minutes.map { max(0, $0) })
        return true
    }
}

@objc(PercolateTurnOffCommand)
final class TurnOffCommand: NSScriptCommand {
    override func performDefaultImplementation() -> Any? {
        AwakeController.shared.deactivate()
        return false
    }
}

@objc(PercolateIsActiveCommand)
final class IsActiveCommand: NSScriptCommand {
    override func performDefaultImplementation() -> Any? {
        AwakeController.shared.isActive
    }
}
