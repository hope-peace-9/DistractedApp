import Cocoa

/// Manages the system status-bar icon and its menu.
///
/// Because LSUIElement = YES hides the Dock icon and menu bar,
/// this status item is the **only** way the user can quit the app.
final class StatusBarController {

    private var statusItem: NSStatusItem?

    // ── Init ──────────────────────────────────────────────────

    init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        configureButton()
        buildMenu()
    }

    deinit {
        if let item = statusItem {
            NSStatusBar.system.removeStatusItem(item)
        }
    }

    // ── Button ────────────────────────────────────────────────

    private func configureButton() {
        guard let button = statusItem?.button else { return }

        // Use a built-in SF Symbol so no asset catalog is needed.
        let image = NSImage(systemSymbolName: "clock.badge.questionmark",
                            accessibilityDescription: "Distracted?")
        image?.isTemplate = true   // automatic light/dark mode support
        button.image = image
    }

    // ── Menu ──────────────────────────────────────────────────

    private func buildMenu() {
        let menu = NSMenu(title: "Distracted?")

        let aboutItem = NSMenuItem(title: "About Distracted?",
                                   action: #selector(showAbout),
                                   keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit",
                                  action: #selector(quitApp),
                                  keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem?.menu = menu
    }

    // ── Actions ───────────────────────────────────────────────

    @objc
    private func showAbout() {
        let alert = NSAlert()
        alert.messageText = "Distracted? (分心了么)"
        alert.informativeText = """
        Time awareness at a glance.

        v1.0.0
        Every \(Int(Constants.defaultFlashInterval / 60)) minutes — a gentle reminder of the time.
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    @objc
    private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}
