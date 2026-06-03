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
    private var appStateCoordinator: AppStateCoordinator?
    private var appearancePrimerWindow: NSWindow?

    // MARK: - Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        print("[Distracted] App launched — PID: \(ProcessInfo.processInfo.processIdentifier)")

        // 1. Accessibility permission self-check (informational only)
        checkAccessibilityPermission()

        // 2. Build the floating overlay window (hidden until first flash)
        overlayWindow = TimeOverlayWindow()

        // 3. Read persisted preferences
        let preferences = PreferencesStore.shared
        let intervalMinutes = preferences.intervalMinutes
        let storedPos = preferences.overlayPositionRawValue
        let storedDur = preferences.durationSeconds
        print("[Distracted] Loaded preferences — interval: \(intervalMinutes) min, position: \(storedPos), duration: \(storedDur)s")

        // 4. Start the absolute-timestamp-backed timer
        let intervalSeconds = preferences.intervalSeconds
        timerService = TimerService(interval: intervalSeconds) { [weak self] in
            self?.showTimeOverlay()
        }

        // 5. Status bar icon — user's only exit (LSUIElement = YES)
        statusBarController = StatusBarController()

        if let timerService, let overlayWindow, let statusBarController {
            appStateCoordinator = AppStateCoordinator(preferences: preferences,
                                                      timerService: timerService,
                                                      overlayWindow: overlayWindow,
                                                      statusBarController: statusBarController)
        }

        // 6. Listen for sleep/wake to recalibrate timer
        registerForPowerNotifications()

        // 7. Prime AppKit so menu-bar NSSwitch renders with accent color on first open
        primeAppKitActiveState()
    }

    // MARK: - AppKit Active-State Priming

    /// [EN] LSUIElement apps launch in an *inactive* NSApp state. AppKit controls
    ///      embedded in `NSMenuItem.view` (such as `NSSwitch`) read `NSApp.isActive`
    ///      when deciding whether to draw the accent-colored "on" track or the
    ///      inactive gray track. Without intervention, the very first time the
    ///      user opens the status-bar menu the switch renders as gray even though
    ///      its state is `.on`. The Settings window doesn't have this problem
    ///      because `showAndFocus()` calls `NSApp.activate(...)`, which flips the
    ///      process into the active state.
    ///
    ///      We fix this at launch with two complementary primers:
    ///      1) Activate NSApp explicitly.
    ///      2) Briefly attach an off-screen, fully transparent `NSWindow` so the
    ///         AppKit window/appearance machinery is initialized before any
    ///         transient menu window is shown. Some macOS builds need this extra
    ///         priming for menu-hosted NSSwitch to pick up the active accent color.
    ///
    /// [CN] LSUIElement 应用启动后 NSApp 默认处于非 active 状态。嵌入到
    ///      `NSMenuItem.view` 中的 AppKit 控件（例如 `NSSwitch`）在决定要画
    ///      强调色轨迹还是失效灰轨迹时，会读取 `NSApp.isActive`。不做处理时，
    ///      用户**首次**打开状态栏菜单看到的开关即使 `state = .on` 也会是灰色。
    ///      设置窗口没有这个问题，是因为 `showAndFocus()` 调用了
    ///      `NSApp.activate(...)`，把进程切到 active。
    ///
    ///      这里在启动时做两层 priming：
    ///      1) 显式激活 NSApp。
    ///      2) 短暂挂一个离屏全透明的 `NSWindow`，让 AppKit 的窗口/外观管理
    ///         在任何菜单窗口出现之前先初始化。某些 macOS 构建需要这一步，
    ///         菜单中的 NSSwitch 才能正确拾取激活强调色。
    ///
    /// [JP] LSUIElement アプリは起動時 NSApp が非アクティブ状態です。
    ///      `NSMenuItem.view` に埋め込まれた AppKit コントロール
    ///      （例: `NSSwitch`）はアクセント色のトラックを描くか
    ///      非アクティブのグレートラックを描くかを決める際に
    ///      `NSApp.isActive` を参照します。対策しないと、ユーザーが
    ///      ステータスメニューを**初めて**開いた時、`state = .on` でも
    ///      スイッチがグレーで表示されます。設定ウィンドウは
    ///      `showAndFocus()` で `NSApp.activate(...)` を呼ぶため
    ///      この問題が出ません。
    ///
    ///      起動時に二段構えで初期化します:
    ///      1) NSApp を明示的に activate する。
    ///      2) 完全に透明なオフスクリーン `NSWindow` を一瞬だけ表示し、
    ///         AppKit のウィンドウ/外観管理を先に初期化する。一部の
    ///         macOS ビルドでは、これがあって初めてメニュー内 NSSwitch が
    ///         アクティブのアクセント色を取得します。
    private func primeAppKitActiveState() {
        NSApp.activate(ignoringOtherApps: true)

        let primer = NSWindow(contentRect: NSRect(x: -10_000, y: -10_000, width: 1, height: 1),
                              styleMask: [.borderless],
                              backing: .buffered,
                              defer: false)
        primer.isReleasedWhenClosed = false
        primer.ignoresMouseEvents = true
        primer.alphaValue = 0
        primer.hasShadow = false
        primer.backgroundColor = .clear
        primer.level = .normal
        primer.orderFrontRegardless()
        appearancePrimerWindow = primer

        DispatchQueue.main.async { [weak self] in
            self?.appearancePrimerWindow?.orderOut(nil)
            self?.appearancePrimerWindow = nil
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        print("[Distracted] App terminating")
        NotificationCenter.default.removeObserver(self)
        NSWorkspace.shared.notificationCenter.removeObserver(self)
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
        let ws = NSWorkspace.shared
        let workspaceNC = ws.notificationCenter

        workspaceNC.addObserver(self,
                                selector: #selector(systemWillSleep),
                                name: NSWorkspace.willSleepNotification,
                                object: nil)
        workspaceNC.addObserver(self,
                                selector: #selector(systemDidWake),
                                name: NSWorkspace.didWakeNotification,
                                object: nil)
        workspaceNC.addObserver(self,
                                selector: #selector(screensDidSleep),
                                name: NSWorkspace.screensDidSleepNotification,
                                object: nil)
        workspaceNC.addObserver(self,
                                selector: #selector(screensDidWake),
                                name: NSWorkspace.screensDidWakeNotification,
                                object: nil)

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(screenParametersDidChange),
                                               name: NSApplication.didChangeScreenParametersNotification,
                                               object: nil)
    }

    @objc
    private func systemWillSleep() {
        print("[Distracted] System will sleep — pausing timer")
        appStateCoordinator?.systemWillSleep()
    }

    @objc
    private func systemDidWake() {
        print("[Distracted] System woke — recalibrating timer")
        appStateCoordinator?.systemDidWake()
    }

    @objc
    private func screensDidSleep() {
        print("[Distracted] Screens slept — pausing visible reminders")
        appStateCoordinator?.screensDidSleep()
    }

    @objc
    private func screensDidWake() {
        print("[Distracted] Screens woke — recalibrating timer")
        appStateCoordinator?.screensDidWake()
    }

    @objc
    private func screenParametersDidChange() {
        print("[Distracted] Screen parameters changed — hiding overlay")
        appStateCoordinator?.screenParametersDidChange()
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
        PreferencesStore.shared.intervalMinutes
    }

    /// [EN] Read persisted position. Falls back to "Center".
    /// [CN] 读取持久化的位置偏好。默认 "Center"。
    /// [JP] 保存された位置設定を読み込む。デフォルトは "Center"。
    private func storedPosition() -> String {
        PreferencesStore.shared.overlayPositionRawValue
    }

    /// [EN] Read persisted duration (seconds). Falls back to 2.
    /// [CN] 读取持久化的停留时间（秒）。默认 2。
    /// [JP] 保存された持続時間（秒）を読み込む。デフォルトは2。
    private func storedDurationSeconds() -> Int {
        PreferencesStore.shared.durationSeconds
    }
}
