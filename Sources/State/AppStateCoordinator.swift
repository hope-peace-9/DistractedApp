import Cocoa

// ═══════════════════════════════════════════════════════════════
//  AppStateCoordinator — Phase 3 state arbitration
// ═══════════════════════════════════════════════════════════════
//
//  [EN] Owns the runtime state transitions between menu toggle,
//       timer, settings preview, sleep/wake, and overlay display.
//
//  [CN] 统一仲裁菜单开关、定时器、设置预览、休眠唤醒与弹窗显示。
//
//  [JP] メニューの切替、タイマー、設定プレビュー、
//       スリープ/復帰、オーバーレイ表示の状態遷移を管理。
// ═══════════════════════════════════════════════════════════════

final class AppStateCoordinator {

    // MARK: - Dependencies

    private let preferences: PreferencesStore
    private let timerService: TimerService
    private let overlayWindow: TimeOverlayWindow
    private let statusBarController: StatusBarController

    private var settingsWindowController: SettingsWindowController?
    private var isSettingsPreviewing = false

    // MARK: - Init

    init(preferences: PreferencesStore,
         timerService: TimerService,
         overlayWindow: TimeOverlayWindow,
         statusBarController: StatusBarController) {
        self.preferences = preferences
        self.timerService = timerService
        self.overlayWindow = overlayWindow
        self.statusBarController = statusBarController

        wireStatusBar()
        statusBarController.updateToggle(isOn: preferences.isEnabled)

        if preferences.isEnabled {
            timerService.resume(recomputeFromNow: false)
        } else {
            timerService.pause()
        }
    }

    // MARK: - Wiring

    private func wireStatusBar() {
        statusBarController.onToggleChange = { [weak self] isEnabled in
            self?.setReminderEnabled(isEnabled)
        }
        statusBarController.onSettingsRequested = { [weak self] in
            self?.openSettings()
        }
    }

    // MARK: - User Intent

    func setReminderEnabled(_ isEnabled: Bool) {
        preferences.isEnabled = isEnabled
        statusBarController.updateToggle(isOn: isEnabled)

        if isSettingsPreviewing {
            timerService.pause()
            return
        }

        if isEnabled {
            timerService.resume(recomputeFromNow: true)
        } else {
            timerService.pause()
            overlayWindow.hideImmediately()
        }
    }

    // MARK: - Settings Preview

    func openSettings() {
        if settingsWindowController == nil {
            let controller = SettingsWindowController(preferences: preferences)
            controller.onDraftChanged = { [weak self] draft in
                self?.previewDraft(draft)
            }
            controller.onConfirm = { [weak self] draft in
                self?.confirmDraft(draft)
            }
            controller.onWindowWillClose = { [weak self] in
                self?.settingsWillClose()
            }
            settingsWindowController = controller
        }

        isSettingsPreviewing = true
        timerService.pause()
        settingsWindowController?.showAndFocus()
    }

    private func settingsWillClose() {
        isSettingsPreviewing = false
        overlayWindow.hideImmediately()

        if preferences.isEnabled {
            timerService.resume(recomputeFromNow: true)
        } else {
            timerService.pause()
        }
    }

    private func previewDraft(_ draft: SettingsDraft) {
        if isSettingsPreviewing {
            overlayWindow.showPreview(configuration: OverlayConfiguration(draft: draft))
        }
    }

    private func confirmDraft(_ draft: SettingsDraft) {
        draft.apply(to: preferences)
        timerService.setInterval(preferences.intervalSeconds)
    }

    // MARK: - System Events

    func systemWillSleep() {
        overlayWindow.hideImmediately()
        timerService.pause()
    }

    func systemDidWake() {
        if isSettingsPreviewing {
            timerService.pause()
            overlayWindow.showPreview()
            return
        }

        if preferences.isEnabled {
            timerService.recalibrate()
        } else {
            timerService.pause()
        }
    }

    func screensDidSleep() {
        overlayWindow.hideImmediately()
        timerService.pause()
    }

    func screensDidWake() {
        systemDidWake()
    }

    func screenParametersDidChange() {
        if isSettingsPreviewing {
            overlayWindow.showPreview()
        } else {
            overlayWindow.hideImmediately()
        }
    }
}
