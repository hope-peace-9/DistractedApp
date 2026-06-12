import Cocoa

// ═══════════════════════════════════════════════════════════════
//  AppStateCoordinator — runtime state arbitration
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

    // MARK: - 依赖

    private let preferences: PreferencesStore
    private let timerService: TimerService
    private let overlayWindow: TimeOverlayWindow
    private let statusBarController: StatusBarController

    private var settingsWindowController: SettingsWindowController?
    private var isSettingsPreviewing = false
    private var didConfirmSettings = false

    // MARK: - 初始化

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

    // MARK: - 回调绑定

    // 将菜单栏动作绑定到统一状态入口，避免 UI 控件直接操作计时器。
    private func wireStatusBar() {
        statusBarController.onToggleChange = { [weak self] isEnabled in
            self?.setReminderEnabled(isEnabled)
        }
        statusBarController.onSettingsRequested = { [weak self] in
            self?.openSettings()
        }
    }

    // MARK: - 用户意图

    // 统一处理提醒开关变化，并根据是否处于设置预览态选择对应的计时器策略。
    func setReminderEnabled(_ isEnabled: Bool) {
        preferences.isEnabled = isEnabled
        statusBarController.updateToggle(isOn: isEnabled)

        if isSettingsPreviewing {
            if isEnabled {
                timerService.restart(interval: preferences.intervalSeconds)
            } else {
                timerService.pause()
            }
            return
        }

        if isEnabled {
            timerService.restart(interval: preferences.intervalSeconds)
        } else {
            timerService.pause()
            overlayWindow.hideImmediately()
        }
    }

    // MARK: - 设置预览

    // 打开设置窗口并进入预览态；窗口复用以避免重复创建 AppKit 控件树。
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
        didConfirmSettings = false
        settingsWindowController?.showAndFocus()
    }

    // 退出预览态时按确认结果决定是否重启计时器，取消则保留原有提醒节奏。
    private func settingsWillClose() {
        let confirmed = didConfirmSettings
        didConfirmSettings = false
        isSettingsPreviewing = false
        overlayWindow.hideImmediately()

        if preferences.isEnabled {
            if confirmed {
                timerService.restart(interval: preferences.intervalSeconds)
            }
        } else {
            timerService.pause()
        }
    }

    // 用内存草稿驱动悬浮窗预览，不写入持久化偏好。
    private func previewDraft(_ draft: SettingsDraft) {
        if isSettingsPreviewing {
            overlayWindow.showPreview(configuration: OverlayConfiguration(draft: draft))
        }
    }

    // 确认后才把草稿写入 PreferencesStore。
    private func confirmDraft(_ draft: SettingsDraft) {
        draft.apply(to: preferences)
        didConfirmSettings = true
    }

    // MARK: - 提醒显示

    // 设置窗口打开时保持提醒节奏继续推进，但不让计划提醒打断实时预览界面。
    func reminderDidFire() {
        guard !isSettingsPreviewing else { return }
        overlayWindow.showAndFadeOut()
    }

    // MARK: - 系统事件

    func systemWillSleep() {
        overlayWindow.hideImmediately()
        timerService.pause()
    }

    func systemDidWake() {
        if isSettingsPreviewing {
            if preferences.isEnabled {
                timerService.recalibrate()
            } else {
                timerService.pause()
            }
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
