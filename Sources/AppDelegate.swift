import Cocoa
import ServiceManagement

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

        promptForLaunchAtLoginIfNeeded(preferences: preferences)

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

    // MARK: - Launch at Login Onboarding

    // [EN] NSAlert has a fixed two-column layout (icon left, text right) that cannot
    //      be overridden with accessoryView tricks. We replace it with a plain
    //      NSWindow whose content view is a proper top-to-bottom Auto Layout stack:
    //        1. App icon   — centered, 80 pt (64 × 1.25)
    //        2. Title      — wrapping label, centered
    //        3. Message    — wrapping label, secondary color, centered
    //        4. Checkbox   — "Don't ask again", centered
    //        5. Button row — Cancel | Yes, right-aligned per HIG
    //
    // [CN] NSAlert 有固定的左图标+右文字两栏结构，无法通过 accessoryView 覆盖。
    //      改用普通 NSWindow，内容视图为纯自上而下的 Auto Layout 布局：
    //        1. App 图标   — 居中，80pt (64 × 1.25)
    //        2. 标题       — 换行标签，居中
    //        3. 正文       — 换行标签，次要颜色，居中
    //        4. 复选框     — "不再询问"，居中
    //        5. 按钮行     — 取消 | 是的，按 HIG 靠右排列
    //
    // [JP] NSAlert は左アイコン・右テキストの2列固定レイアウトで、
    //      accessoryView では上書きできない。通常の NSWindow に置き換え、
    //      content view を純粋な縦方向 Auto Layout で構成する：
    //        1. App アイコン  — 中央揃え、80pt (64 × 1.25)
    //        2. タイトル      — 折り返しラベル、中央揃え
    //        3. メッセージ    — 折り返しラベル、セカンダリカラー、中央揃え
    //        4. チェックボックス — "今後表示しない"、中央揃え
    //        5. ボタン行      — キャンセル | はい、HIG に従い右揃え
    private func promptForLaunchAtLoginIfNeeded(preferences: PreferencesStore) {
        guard !preferences.hasPromptedForStartup else { return }

        let status = SMAppService.mainApp.status
        guard status == .notFound || status == .notRegistered else { return }

        NSApp.activate(ignoringOtherApps: true)

        let (window, checkbox, handler) = buildStartupWindow()
        window.center()
        window.makeKeyAndOrderFront(nil)
        let response = NSApp.runModal(for: window)
        window.orderOut(nil)
        _ = handler

        if checkbox.state == .on {
            preferences.hasPromptedForStartup = true
        }

        guard response == .OK else { return }

        do {
            try SMAppService.mainApp.register()
            print("[Distracted] Launch at login registration requested")
        } catch {
            print("[Distracted] Failed to register launch at login: \(error)")
        }

        if let url = URL(string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension") {
            NSWorkspace.shared.open(url)
        }
    }

    private static func bundleAppIconImage() -> NSImage {
        if let named = NSImage(named: "AppIcon") {
            return named
        }
        if let url = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
           let fromBundle = NSImage(contentsOf: url) {
            return fromBundle
        }
        return NSApp.applicationIconImage ?? NSImage()
    }

    private func buildStartupWindow() -> (NSWindow, NSButton, StartupModalHandler) {
        let handler      = StartupModalHandler()
        let windowWidth  : CGFloat = 300
        let windowHeight : CGFloat = 288
        let hPad         : CGFloat = 24
        let iconSize     : CGFloat = 64 * 1.25

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: windowWidth, height: windowHeight),
            styleMask:   [.titled, .fullSizeContentView],
            backing:     .buffered,
            defer:       false)
        window.isReleasedWhenClosed        = false
        window.titlebarAppearsTransparent  = true
        window.titleVisibility             = .hidden
        window.isMovableByWindowBackground = true
        window.standardWindowButton(.closeButton)?.isHidden     = true
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden      = true

        guard let cv = window.contentView else {
            return (window, NSButton(), handler)
        }

        // 1. Icon
        let iconView = NSImageView(image: Self.bundleAppIconImage())
        iconView.imageScaling = .scaleProportionallyUpOrDown
        iconView.translatesAutoresizingMaskIntoConstraints = false

        // 2. Title
        let titleField = NSTextField(labelWithString: L10n.alertStartupTitle)
        titleField.font                  = .systemFont(ofSize: 14, weight: .semibold)
        titleField.alignment             = .center
        titleField.lineBreakMode         = .byWordWrapping
        titleField.maximumNumberOfLines  = 0
        titleField.preferredMaxLayoutWidth = windowWidth - hPad * 2
        titleField.translatesAutoresizingMaskIntoConstraints = false

        // 3. Message
        let msgField = NSTextField(labelWithString: L10n.alertStartupMessage)
        msgField.font                  = .systemFont(ofSize: NSFont.smallSystemFontSize)
        msgField.textColor             = .secondaryLabelColor
        msgField.alignment             = .center
        msgField.lineBreakMode         = .byWordWrapping
        msgField.maximumNumberOfLines  = 0
        msgField.preferredMaxLayoutWidth = windowWidth - hPad * 2
        msgField.translatesAutoresizingMaskIntoConstraints = false

        // 4. Checkbox
        let checkbox = NSButton(checkboxWithTitle: L10n.alertStartupDontAskAgain,
                                target: nil, action: nil)
        checkbox.state = .off
        checkbox.translatesAutoresizingMaskIntoConstraints = false

        // 5. Buttons (centered)
        let cancelBtn = NSButton(title: L10n.alertCancel,
                                 target: handler,
                                 action: #selector(StartupModalHandler.cancel(_:)))
        cancelBtn.bezelStyle    = .rounded
        cancelBtn.keyEquivalent = "\u{1B}"
        cancelBtn.translatesAutoresizingMaskIntoConstraints = false

        let confirmBtn = NSButton(title: L10n.alertStartupYes,
                                  target: handler,
                                  action: #selector(StartupModalHandler.confirm(_:)))
        confirmBtn.bezelStyle    = .rounded
        confirmBtn.keyEquivalent = "\r"
        confirmBtn.translatesAutoresizingMaskIntoConstraints = false

        let buttonRow = NSStackView(views: [cancelBtn, confirmBtn])
        buttonRow.orientation = .horizontal
        buttonRow.spacing     = 8
        buttonRow.translatesAutoresizingMaskIntoConstraints = false

        [iconView, titleField, msgField, checkbox, buttonRow].forEach { cv.addSubview($0) }

        NSLayoutConstraint.activate([
            // 1. Icon — centered at top
            iconView.widthAnchor.constraint(equalToConstant: iconSize),
            iconView.heightAnchor.constraint(equalToConstant: iconSize),
            iconView.centerXAnchor.constraint(equalTo: cv.centerXAnchor),
            iconView.topAnchor.constraint(equalTo: cv.topAnchor, constant: 20),

            // 2. Title below icon
            titleField.topAnchor.constraint(equalTo: iconView.bottomAnchor, constant: 10),
            titleField.leadingAnchor.constraint(equalTo: cv.leadingAnchor, constant: hPad),
            titleField.trailingAnchor.constraint(equalTo: cv.trailingAnchor, constant: -hPad),

            // 3. Message below title
            msgField.topAnchor.constraint(equalTo: titleField.bottomAnchor, constant: 6),
            msgField.leadingAnchor.constraint(equalTo: cv.leadingAnchor, constant: hPad),
            msgField.trailingAnchor.constraint(equalTo: cv.trailingAnchor, constant: -hPad),

            // 4. Checkbox below message, centered
            checkbox.topAnchor.constraint(equalTo: msgField.bottomAnchor, constant: 12),
            checkbox.centerXAnchor.constraint(equalTo: cv.centerXAnchor),

            // 5. Buttons below checkbox, centered
            buttonRow.topAnchor.constraint(equalTo: checkbox.bottomAnchor, constant: 16),
            buttonRow.centerXAnchor.constraint(equalTo: cv.centerXAnchor),
            buttonRow.bottomAnchor.constraint(equalTo: cv.bottomAnchor, constant: -16)
        ])

        return (window, checkbox, handler)
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

// MARK: - Startup Modal Handler

private final class StartupModalHandler: NSObject {
    @objc func confirm(_ sender: Any?) { NSApp.stopModal(withCode: .OK) }
    @objc func cancel(_ sender: Any?)  { NSApp.stopModal(withCode: .cancel) }
}
