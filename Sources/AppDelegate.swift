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

    // MARK: - 组件

    private var statusBarController: StatusBarController?
    private var timerService: TimerService?
    private var overlayWindow: TimeOverlayWindow?
    private var appStateCoordinator: AppStateCoordinator?
    private var appearancePrimerWindow: NSWindow?

    // MARK: - 生命周期

    func applicationDidFinishLaunching(_ notification: Notification) {
        print("[Distracted] App launched — PID: \(ProcessInfo.processInfo.processIdentifier)")

        checkAccessibilityPermission()

        overlayWindow = TimeOverlayWindow()

        let preferences = PreferencesStore.shared
        let intervalMinutes = preferences.intervalMinutes
        let storedPos = preferences.overlayPositionRawValue
        let storedDur = preferences.durationSeconds
        print("[Distracted] Loaded preferences — interval: \(intervalMinutes) min, position: \(storedPos), duration: \(storedDur)s")

        promptForLaunchAtLoginIfNeeded(preferences: preferences)

        let intervalSeconds = preferences.intervalSeconds
        timerService = TimerService(interval: intervalSeconds) { [weak self] in
            self?.showTimeOverlay()
        }

        statusBarController = StatusBarController()

        if let timerService, let overlayWindow, let statusBarController {
            appStateCoordinator = AppStateCoordinator(preferences: preferences,
                                                      timerService: timerService,
                                                      overlayWindow: overlayWindow,
                                                      statusBarController: statusBarController)
        }

        registerForPowerNotifications()

        primeAppKitActiveState()
    }

    // MARK: - 登录启动引导

    // NSAlert 的固定图标与文字布局不适合这个引导弹窗，因此使用小型自定义窗口保持内容居中紧凑。
    private func promptForLaunchAtLoginIfNeeded(preferences: PreferencesStore) {
        guard !preferences.hasPromptedForStartup else { return }

        let status = SMAppService.mainApp.status
        guard status == .notFound || status == .notRegistered else { return }

        NSApp.activate(ignoringOtherApps: true)

        let startupPrompt = buildStartupWindow()
        startupPrompt.window.center()
        startupPrompt.window.makeKeyAndOrderFront(nil)
        let response = NSApp.runModal(for: startupPrompt.window)
        startupPrompt.window.orderOut(nil)

        if startupPrompt.checkbox.state == .on {
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

    // 优先读取 bundle 内应用图标，缺失时回退到系统提供的应用图标。
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

    // 构建登录启动引导窗口，并返回模态回调处理器以维持 target 生命周期。
    private func buildStartupWindow() -> (window: NSWindow, checkbox: NSButton, handler: StartupModalHandler) {
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

        let iconView = NSImageView(image: Self.bundleAppIconImage())
        iconView.imageScaling = .scaleProportionallyUpOrDown
        iconView.translatesAutoresizingMaskIntoConstraints = false

        let titleField = NSTextField(labelWithString: L10n.alertStartupTitle)
        titleField.font                  = .systemFont(ofSize: 14, weight: .semibold)
        titleField.alignment             = .center
        titleField.lineBreakMode         = .byWordWrapping
        titleField.maximumNumberOfLines  = 0
        titleField.preferredMaxLayoutWidth = windowWidth - hPad * 2
        titleField.translatesAutoresizingMaskIntoConstraints = false

        let msgField = NSTextField(labelWithString: L10n.alertStartupMessage)
        msgField.font                  = .systemFont(ofSize: NSFont.smallSystemFontSize)
        msgField.textColor             = .secondaryLabelColor
        msgField.alignment             = .center
        msgField.lineBreakMode         = .byWordWrapping
        msgField.maximumNumberOfLines  = 0
        msgField.preferredMaxLayoutWidth = windowWidth - hPad * 2
        msgField.translatesAutoresizingMaskIntoConstraints = false

        let checkbox = NSButton(checkboxWithTitle: L10n.alertStartupDontAskAgain,
                                target: nil, action: nil)
        checkbox.state = .off
        checkbox.translatesAutoresizingMaskIntoConstraints = false

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
            iconView.widthAnchor.constraint(equalToConstant: iconSize),
            iconView.heightAnchor.constraint(equalToConstant: iconSize),
            iconView.centerXAnchor.constraint(equalTo: cv.centerXAnchor),
            iconView.topAnchor.constraint(equalTo: cv.topAnchor, constant: 20),

            titleField.topAnchor.constraint(equalTo: iconView.bottomAnchor, constant: 10),
            titleField.leadingAnchor.constraint(equalTo: cv.leadingAnchor, constant: hPad),
            titleField.trailingAnchor.constraint(equalTo: cv.trailingAnchor, constant: -hPad),

            msgField.topAnchor.constraint(equalTo: titleField.bottomAnchor, constant: 6),
            msgField.leadingAnchor.constraint(equalTo: cv.leadingAnchor, constant: hPad),
            msgField.trailingAnchor.constraint(equalTo: cv.trailingAnchor, constant: -hPad),

            checkbox.topAnchor.constraint(equalTo: msgField.bottomAnchor, constant: 12),
            checkbox.centerXAnchor.constraint(equalTo: cv.centerXAnchor),

            buttonRow.topAnchor.constraint(equalTo: checkbox.bottomAnchor, constant: 16),
            buttonRow.centerXAnchor.constraint(equalTo: cv.centerXAnchor),
            buttonRow.bottomAnchor.constraint(equalTo: cv.bottomAnchor, constant: -16)
        ])

        return (window, checkbox, handler)
    }

    // MARK: - AppKit 激活态预热

    /// LSUIElement 应用可能以非 active 的 NSApp 状态启动。NSSwitch 等菜单内控件会读取该状态决定强调色，
    /// 因此首次打开菜单时可能把已开启的开关画成失效灰色。这里通过短暂挂载离屏窗口提前预热 AppKit 状态。
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

    // MARK: - AX 权限自检

    // 仅输出辅助功能权限状态；当前应用不依赖该权限运行。
    private func checkAccessibilityPermission() {
        if AXIsProcessTrusted() {
            print("[Distracted] ✓ Accessibility permission granted (not required)")
        } else {
            print("[Distracted] ℹ️  Accessibility permission not granted — no action needed")
        }
    }

    // MARK: - 电源通知

    // 监听系统休眠、唤醒与屏幕参数变化，用于校准计时器和清理可见弹窗。
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

    // MARK: - 悬浮窗显示

    /// [EN] Triggered by TimerService when the interval boundary is reached
    ///      (or on wake if a flash was missed during sleep).
    ///      The overlay window reads position + duration from UserDefaults on its own.
    /// [CN] 由 TimerService 在间隔边界到达时（或唤醒后发现错过提醒时）触发。
    ///      弹窗内部自行读取 UserDefaults 中的位置和停留时间。
    /// [JP] インターバル境界到達時（またはウェイク時の取りこぼし検出時）に
    ///      TimerService から呼び出される。オーバーレイ内で UserDefaults から
    ///      位置と持続時間を自ら読み取る。
    private func showTimeOverlay() {
        if let appStateCoordinator {
            appStateCoordinator.reminderDidFire()
        } else {
            overlayWindow?.showAndFadeOut()
        }
    }
}

// MARK: - 启动模态处理器

private final class StartupModalHandler: NSObject {
    @objc func confirm(_ sender: Any?) { NSApp.stopModal(withCode: .OK) }
    @objc func cancel(_ sender: Any?)  { NSApp.stopModal(withCode: .cancel) }
}
