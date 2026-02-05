import Cocoa
import ApplicationServices

class PermissionManager {
    static let shared = PermissionManager()

    private init() {}

    func checkAccessibilityPermission() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): false] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)

        if !trusted {
            showAccessibilityInstructions()
        }
    }

    private func showAccessibilityInstructions() {
        let alert = NSAlert()
        alert.messageText = "Accessibility Permission Required"
        alert.informativeText = """
        SwipeType needs Accessibility permission to:
        • Detect the global Shift+Tab hotkey
        • Insert text into other applications

        Please grant permission in System Settings > Privacy & Security > Accessibility.

        After granting permission, you may need to restart SwipeType.
        """
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Later")

        let response = alert.runModal()

        if response == .alertFirstButtonReturn {
            openAccessibilitySettings()
        }
    }

    func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }

    func startMonitoringPermission(onChange: @escaping (Bool) -> Void) {
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }

            let granted = self.checkAccessibilityPermission()
            onChange(granted)

            if granted {
                timer.invalidate()
            }
        }
    }
}
