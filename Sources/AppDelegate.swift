import Cocoa

// ═══════════════════════════════════════════════════════════════
//  AppDelegate — application lifecycle & component wiring
// ═══════════════════════════════════════════════════════════════
//
//  [EN] Responsibilities:
//       1. Assemble all components (overlay, timer, status bar).
//       2. Wire StatusBarController callbacks → TimerService / overlay.
//       3. Listen for NSWorkspace sleep/wake → TimerService pause/recalibrate.
//       4. Self-check AX permission (informational only).
//
//  [CN] 职责：
//       1. 组装所有组件（弹窗、定时器、状态栏）。
//       2. 将菜单栏回调连接到定时器/弹窗。
//       3. 监听系统休眠/唤醒 → 定时器暂停/校准。
//       4. AX 权限自检（仅信息提示）。
//
//  [JP] 責務：
//       1. 全コンポーネント（オーバーレイ、タイマー、ステータスバー）を組み立て。
//       2. ステータスバーのコールバックをタイマー/オーバーレイに接続。
//       3. システムのスリープ/ウェイクを監視 → タイマーの一時停止/再調整。
//       4. AX 権限のセルフチェック（情報表示のみ）。
// ═══════════════════════════════════════════════════════════════

final class AppDelegate: NSObject, NSApplicationDelegate {

    // MARK: - Components

    private var statusBarController: StatusBarController?
    private var timerService: TimerService?
    private var overlayWindow: TimeOverlayWindow?

    // MARK: - Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        print("[Distracted] App launched — PID: \(ProcessInfo.processInfo.processIdentifier)")

        // 1. Accessibility permission self-check (informational only)
        checkAccessibilityPermission()

        // 2. Build the floating overlay window (hidden until first flash)
        overlayWindow = TimeOverlayWindow()

        // 3. Read persisted preferences
        let intervalMinutes = storedIntervalMinutes()
        let storedPos = storedPosition()
        let storedDur = storedDurationSeconds()
        print("[Distracted] Loaded preferences — interval: \(intervalMinutes) min, position: \(storedPos), duration: \(storedDur)s")

        // 4. Start the absolute-timestamp-backed timer
        let intervalSeconds = TimeInterval(intervalMinutes * 60)
        timerService = TimerService(interval: intervalSeconds) { [weak self] in
            DispatchQueue.main.async {
                self?.showTimeOverlay()
            }
        }

        // 5. Status bar icon — user's only exit (LSUIElement = YES)
        statusBarController = StatusBarController()

        // [EN] Wire: interval change → TimerService.setInterval()
        // [CN] 连线：间隔变更 → TimerService.setInterval()
        // [JP] 配線：間隔変更 → TimerService.setInterval()
        statusBarController?.onIntervalChange = { [weak self] newIntervalSeconds in
            self?.timerService?.setInterval(newIntervalSeconds)
        }

        // [EN] Wire: position change → log only (overlay reads from UserDefaults at flash time)
        // [CN] 连线：位置变更 → 仅记日志（弹窗闪烁时从 UserDefaults 读取）
        // [JP] 配線：位置変更 → ログのみ（点滅時にオーバーレイが UserDefaults から読み込む）
        statusBarController?.onPositionChange = { newPosition in
            print("[Distracted] Position preference updated to: \(newPosition)")
        }

        // [EN] Wire: duration change → log only (overlay reads from UserDefaults at flash time)
        // [CN] 连线：停留时间变更 → 仅记日志（弹窗闪烁时从 UserDefaults 读取）
        // [JP] 配線：持続時間変更 → ログのみ（点滅時にオーバーレイが UserDefaults から読み込む）
        statusBarController?.onDurationChange = { newDuration in
            print("[Distracted] Duration preference updated to: \(newDuration)s")
        }

        // 6. Listen for sleep/wake to recalibrate timer
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

    /// [EN] Triggered by TimerService when the interval boundary is reached
    ///      (or on wake if a flash was missed during sleep).
    ///      The overlay window reads position + duration from UserDefaults on its own.
    /// [CN] 由 TimerService 在间隔边界到达时（或唤醒后发现错过提醒时）触发。
    ///      弹窗内部自行读取 UserDefaults 中的位置和停留时间。
    /// [JP] インターバル境界到達時（またはウェイク時の取りこぼし検出時）に
    ///      TimerService から呼び出される。オーバーレイ内で UserDefaults から
    ///      位置と持続時間を自ら読み取る。
    private func showTimeOverlay() {
        overlayWindow?.showAndFadeOut()
    }

    // MARK: - UserDefaults helpers

    /// [EN] Read persisted interval (minutes). Falls back to 30 if unset / invalid.
    /// [CN] 读取持久化的间隔（分钟）。未设置或无效时默认 30。
    /// [JP] 保存された間隔（分）を読み込む。未設定や無効値の場合はデフォルト30。
    private func storedIntervalMinutes() -> Int {
        let stored = UserDefaults.standard.integer(forKey: Constants.UserDefaultsKey.intervalMinutes)
        return stored > 0 ? stored : 30
    }

    /// [EN] Read persisted position. Falls back to "Center".
    /// [CN] 读取持久化的位置偏好。默认 "Center"。
    /// [JP] 保存された位置設定を読み込む。デフォルトは "Center"。
    private func storedPosition() -> String {
        UserDefaults.standard.string(forKey: Constants.UserDefaultsKey.position)
            ?? Constants.Position.center.rawValue
    }

    /// [EN] Read persisted duration (seconds). Falls back to 2.
    /// [CN] 读取持久化的停留时间（秒）。默认 2。
    /// [JP] 保存された持続時間（秒）を読み込む。デフォルトは2。
    private func storedDurationSeconds() -> Int {
        let stored = UserDefaults.standard.integer(forKey: Constants.UserDefaultsKey.durationSeconds)
        return stored > 0 ? stored : Constants.defaultDurationSeconds
    }
}
