import Cocoa

// ═══════════════════════════════════════════════════════════════
//  StatusBarController — Menu bar icon & interactive menu
// ═══════════════════════════════════════════════════════════════
//
//  [EN] Because LSUIElement = YES hides the Dock icon and menu bar,
//       this status item is the **only** way the user can quit the app.
//       Responsibilities:
//       1. Show a status-bar icon (SF Symbol).
//       2. Provide Position & Interval submenus that reflect UserDefaults.
//       3. Custom interval input dialog with validation.
//       4. Notify listeners on preference changes.
//
//  [CN] 由于 LSUIElement = YES 隐藏了 Dock 图标和全局菜单栏，
//       该状态栏图标是用户退出应用的**唯一**入口。
//       职责：渲染菜单、读写 UserDefaults、回调通知。
//
//  [JP] LSUIElement = YES のため Dock アイコンとメニューバーは非表示。
//       このステータスアイテムが終了の**唯一**の手段です。
// ═══════════════════════════════════════════════════════════════

final class StatusBarController {

    // MARK: - Properties

    private var statusItem: NSStatusItem?
    private var menu: NSMenu?

    // [EN] Callbacks wired from AppDelegate to propagate changes.
    // [CN] 由 AppDelegate 挂载的回调，用于传递变更。
    // [JP] AppDelegate から設定されるコールバック。
    var onIntervalChange: ((TimeInterval) -> Void)?
    var onPositionChange: ((String) -> Void)?

    // [EN] Intervals (in minutes) shown as preset options in the menu.
    // [CN] 菜单中显示的预设间隔选项（单位：分钟）。
    // [JP] メニューに表示するプリセット間隔（分）。
    private static let presetIntervals: [Int] = [15, 30, 60, 120]

    // MARK: - Init

    init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        configureButton()
        rebuildMenu()
    }

    deinit {
        if let item = statusItem {
            NSStatusBar.system.removeStatusItem(item)
        }
    }

    // MARK: - Button

    private func configureButton() {
        guard let button = statusItem?.button else { return }
        let image = NSImage(systemSymbolName: "clock.badge.questionmark",
                            accessibilityDescription: "Distracted?")
        image?.isTemplate = true
        button.image = image
    }

    // MARK: - Menu (full rebuild on every change)

    // [EN] Rebuild the entire menu tree to reflect the latest UserDefaults state.
    // [CN] 完整重建菜单树，以反映最新的 UserDefaults 状态。
    // [JP] 最新の UserDefaults 状態を反映するためメニュー全体を再構築。
    func rebuildMenu() {
        let m = NSMenu(title: "Distracted?")

        // ── About ─────────────────────────────────────────────
        let aboutItem = NSMenuItem(title: "About Distracted?",
                                   action: #selector(showAbout),
                                   keyEquivalent: "")
        aboutItem.target = self
        m.addItem(aboutItem)
        m.addItem(.separator())

        // ── Position submenu ───────────────────────────────────
        let currentPos = storedPosition()
        let posMenu = NSMenu(title: "Position")
        for pos in Constants.Position.allCases {
            let raw = pos.rawValue
            let item = NSMenuItem(title: raw,
                                  action: #selector(didSelectPosition(_:)),
                                  keyEquivalent: "")
            item.target = self
            item.representedObject = raw
            if raw == currentPos {
                item.state = .on   // [EN] show checkmark  [CN] 显示勾号  [JP] チェックマーク表示
            }
            posMenu.addItem(item)
        }
        let posContainer = NSMenuItem(title: "Position", action: nil, keyEquivalent: "")
        posContainer.submenu = posMenu
        m.addItem(posContainer)

        // ── Interval submenu ───────────────────────────────────
        let currentInterval = storedIntervalMinutes()
        let intMenu = NSMenu(title: "Interval")

        for preset in Self.presetIntervals {
            let label = "\(preset) min"
            let item = NSMenuItem(title: label,
                                  action: #selector(didSelectIntervalPreset(_:)),
                                  keyEquivalent: "")
            item.target = self
            item.representedObject = preset
            if preset == currentInterval {
                item.state = .on
            }
            intMenu.addItem(item)
        }

        intMenu.addItem(.separator())

        let customItem = NSMenuItem(title: "Custom…",
                                    action: #selector(didRequestCustomInterval),
                                    keyEquivalent: "")
        customItem.target = self
        // [EN] Checkmark on Custom when interval doesn't match any preset.
        // [CN] 当间隔不匹配任何预设时，Custom 选项显示勾号。
        // [JP] 設定値がどのプリセットにも一致しない場合、Custom にチェック。
        if !Self.presetIntervals.contains(currentInterval) {
            customItem.state = .on
        }
        intMenu.addItem(customItem)

        let intContainer = NSMenuItem(title: "Interval", action: nil, keyEquivalent: "")
        intContainer.submenu = intMenu
        m.addItem(intContainer)

        m.addItem(.separator())

        // ── Quit ──────────────────────────────────────────────
        let quitItem = NSMenuItem(title: "Quit",
                                  action: #selector(quitApp),
                                  keyEquivalent: "q")
        quitItem.target = self
        m.addItem(quitItem)

        statusItem?.menu = m
        menu = m
    }

    // MARK: - Position actions

    @objc
    private func didSelectPosition(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String else { return }
        UserDefaults.standard.set(raw, forKey: Constants.UserDefaultsKey.position)
        print("[Distracted] Position changed to: \(raw)")
        onPositionChange?(raw)
        rebuildMenu()
    }

    // MARK: - Interval preset actions

    @objc
    private func didSelectIntervalPreset(_ sender: NSMenuItem) {
        guard let minutes = sender.representedObject as? Int else { return }
        saveAndApplyInterval(minutes)
    }

    // [EN] Validate, persist, and apply a custom interval value.
    // [CN] 校验、持久化并应用自定义间隔值。
    // [JP] カスタム間隔の検証・保存・適用。
    @objc
    private func didRequestCustomInterval() {
        // [EN] Build a simple NSAlert with a text field.
        // [CN] 构建带文本输入框的 NSAlert。
        // [JP] テキストフィールド付きの NSAlert を構築。
        let alert = NSAlert()
        alert.messageText = "Custom Interval"
        alert.informativeText = "Enter minutes (1 – 1440):"
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")

        let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 140, height: 24))
        textField.placeholderString = "e.g. 45"
        textField.stringValue = "\(storedIntervalMinutes())"
        alert.accessoryView = textField

        let resp = alert.runModal()
        guard resp == .alertFirstButtonReturn else { return }

        let raw = textField.stringValue.trimmingCharacters(in: .whitespaces)

        // [EN] Validate: must be integer within [1, 1440].
        // [CN] 校验：必须是整数，且范围在 1～1440。
        // [JP] 検証：整数かつ 1～1440 の範囲内。
        guard let minutes = Int(raw), minutes >= 1, minutes <= 1440 else {
            let errAlert = NSAlert()
            errAlert.messageText = "Invalid Input"
            errAlert.informativeText = "Please enter a whole number between 1 and 1440."
            errAlert.alertStyle = .critical
            errAlert.addButton(withTitle: "OK")
            errAlert.runModal()
            return
        }

        saveAndApplyInterval(minutes)
    }

    // [EN] Shared helper: persist to UserDefaults, fire callback, rebuild menu.
    // [CN] 通用助手：写入 UserDefaults、触发回调、重建菜单。
    // [JP] 共通ヘルパー：UserDefaults に保存、コールバック実行、メニュー再構築。
    private func saveAndApplyInterval(_ minutes: Int) {
        UserDefaults.standard.set(minutes, forKey: Constants.UserDefaultsKey.intervalMinutes)
        print("[Distracted] Interval changed to: \(minutes) min")
        let intervalSeconds = TimeInterval(minutes * 60)
        onIntervalChange?(intervalSeconds)
        rebuildMenu()
    }

    // MARK: - UserDefaults helpers

    /// [EN] Read stored interval in minutes; fall back to default 30.
    /// [CN] 读取持久化的间隔分钟数，默认 30 分钟。
    /// [JP] 保存された間隔（分）を読む。デフォルトは30分。
    private func storedIntervalMinutes() -> Int {
        let stored = UserDefaults.standard.integer(forKey: Constants.UserDefaultsKey.intervalMinutes)
        return stored > 0 ? stored : 30
    }

    /// [EN] Read stored position; fall back to "Center".
    /// [CN] 读取持久化的位置；默认 "Center"。
    /// [JP] 保存された位置を読む。デフォルトは "Center"。
    private func storedPosition() -> String {
        UserDefaults.standard.string(forKey: Constants.UserDefaultsKey.position) ?? Constants.Position.center.rawValue
    }

    // MARK: - Other actions

    @objc
    private func showAbout() {
        let alert = NSAlert()
        alert.messageText = "Distracted? (分心了么)"
        alert.informativeText = """
        Time awareness at a glance.

        v1.0.0
        Every \(storedIntervalMinutes()) min — a gentle reminder of the time.
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
