import Cocoa

final class AppDelegate: NSObject, NSApplicationDelegate {

    // MARK: - Components
    private var statusBarController: StatusBarController?
    private var timerService: TimerService?
    private var overlayWindow: TimeOverlayWindow?

    // MARK: - Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        print("[Distracted] App launched — PID: \(ProcessInfo.processInfo.processIdentifier)")

        // 1. Self-check: Accessibility permission (informational only,
        //    our overlay does NOT require it per architecture constraints)
        checkAccessibilityPermission()

        // 2. Build the floating overlay window (hidden until first flash)
        overlayWindow = TimeOverlayWindow()

        // 3. Status bar icon — user's only exit (LSUIElement = YES)
        statusBarController = StatusBarController()

        // 4. Start the absolute-timestamp-backed timer
        timerService = TimerService { [weak self] in
            self?.showTimeOverlay()
        }

        // 5. Listen for sleep/wake to recalibrate timer
        registerForPowerNotifications()
    }

    func applicationWillTerminate(_ notification: Notification) {
        print("[Distracted] App terminating")
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - AX Permission Self-Check

    private func checkAccessibilityPermission() {
        if AXIsProcessTrusted() {
            print("[Distracted] ✓ Accessibility permission granted (not required)")
        } else {
            // ⚠️  As per architecture constraints, our overlay does NOT
            //     depend on AX permission. This is purely informational.
            print("[Distracted] ℹ️  Accessibility permission not granted — no action needed")
        }
    }

    // MARK: - Power Notifications (Wake / Sleep)

    private func registerForPowerNotifications() {
        let nc = NotificationCenter.default
        let ws = NSWorkspace.shared

        nc.addObserver(self,
                       selector: #selector(systemWillSleep),
                       name: NSWorkspace.willSleepNotification,
                       object: ws)
        nc.addObserver(self,
                       selector: #selector(systemDidWake),
                       name: NSWorkspace.didWakeNotification,
                       object: ws)
    }

    @objc
    private func systemWillSleep() {
        print("[Distracted] System will sleep — pausing timer")
        timerService?.pause()
    }

    @objc
    private func systemDidWake() {
        print("[Distracted] System woke — recalibrating timer")
        timerService?.recalibrate()
    }

    // MARK: - Overlay Display

    private func showTimeOverlay() {
        guard let overlay = overlayWindow else { return }

        // Dynamic multi-screen check before every flash
        overlay.positionOnActiveScreen()

        // Show time with auto-fade
        overlay.flashCurrentTime()
    }
}
