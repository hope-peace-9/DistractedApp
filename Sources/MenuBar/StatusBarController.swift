import Cocoa

// ═══════════════════════════════════════════════════════════════
//  StatusBarController — minimal Phase 3 menu bar surface
// ═══════════════════════════════════════════════════════════════
//
//  [EN] LSUIElement apps need a reliable menu-bar exit path. Phase 3
//       keeps the menu tiny: Toggle, Settings..., Quit.
//
//  [CN] LSUIElement 应用必须保留可靠的菜单栏退出入口。Phase 3
//       将菜单压缩为：开关、设置、退出。
//
//  [JP] LSUIElement アプリには確実な終了導線が必要。Phase 3 では
//       メニューを「切替、設定、終了」に絞る。
// ═══════════════════════════════════════════════════════════════

final class StatusBarController: NSObject {

    private static let menubarIconPointSize: CGFloat = 18
    /// [EN] Logical gap (pt) between status-item bottom and menu top — scales on 1x/2x.
    /// [CN] 状态项底边与菜单顶边之间的逻辑间距（pt），在 1x/2x 屏上自适应。
    /// [JP] ステータス項目下端とメニュー上端の論理間隔（pt）。1x/2x でスケール。
    private static let menuPopUpScreenGap: CGFloat = 10
    /// [EN] Matches `makeToggleItem` row width for multi-monitor X clamping.
    /// [CN] 与 `makeToggleItem` 行宽一致，用于多显示器 X 轴边界钳制。
    /// [JP] `makeToggleItem` の行幅と一致。マルチディスプレイの X クランプ用。
    private static let estimatedMenuWidth: CGFloat = 220

    // MARK: - Properties

    private var statusItem: NSStatusItem?
    private var menu: NSMenu?
    private weak var toggleSwitch: NSSwitch?
    private var isToggleOn = PreferencesStore.shared.isEnabled

    var onToggleChange: ((Bool) -> Void)?
    var onSettingsRequested: (() -> Void)?

    // MARK: - Init

    override init() {
        super.init()
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        configureButton()
        rebuildMenu()
    }

    deinit {
        if let item = statusItem {
            NSStatusBar.system.removeStatusItem(item)
        }
    }

    // MARK: - Public API

    func updateToggle(isOn: Bool) {
        isToggleOn = isOn
        refreshToggleView()
    }

    // MARK: - Button

    private func configureButton() {
        guard let button = statusItem?.button else { return }
        button.image = loadMenubarIcon()
        // [EN] Do NOT rely on `statusItem.menu` auto-popup while inactive.
        //      Assigning `statusItem.menu` makes AppKit open the menu before
        //      activation finishes, which dismisses it on the first click.
        //      We handle the click ourselves: activate first, then popUp.
        // [CN] 不要在非 active 时依赖 `statusItem.menu` 的自动弹出。
        //      挂上 `statusItem.menu` 会在 activate 完成前就弹菜单，导致首次点击闪退。
        //      改由自定义点击：先 activate，再手动 popUp。
        // [JP] 非アクティブ時に `statusItem.menu` の自動表示に頼らない。
        //      menu を直接割り当てると activate 完了前に開き、初回クリックで消える。
        //      クリックを自前処理し、先に activate してから popUp する。
        button.target = self
        button.action = #selector(statusBarButtonClicked(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    /// [EN] Rasterise the bundled menubar asset into a single 18×18 pt template image.
    ///      Setting `.size` alone is not enough — huge @2x bitmaps still draw as a
    ///      clipped black block unless we bake one representation at the target size.
    /// [CN] 将 bundle 中的 menubar 资源光栅化为单个 18×18 pt 模板图。
    ///      仅设置 `.size` 不够 —— 大尺寸 @2x 位图仍会显示为被裁切的黑块。
    /// [JP] バンドル内 menubar を 18×18 pt の単一テンプレート画像にラスタライズする。
    ///      `.size` だけでは不十分で、巨大な @2x ビットマップは黒い塊になる。
    private func loadMenubarIcon() -> NSImage? {
        guard let source = NSImage(named: "menubar") else { return nil }

        let side = Self.menubarIconPointSize
        let target = NSSize(width: side, height: side)
        let icon = NSImage(size: target)
        icon.isTemplate = true

        icon.lockFocus()
        if let ctx = NSGraphicsContext.current {
            ctx.imageInterpolation = .high
        }
        let from = NSRect(origin: .zero, size: source.size)
        let to = NSRect(origin: .zero, size: target)
        source.draw(in: to, from: from, operation: .sourceOver, fraction: 1.0)
        icon.unlockFocus()

        return icon
    }

    // MARK: - Menu

    private func rebuildMenu() {
        let m = NSMenu(title: L10n.appName)
        m.delegate = self
        m.addItem(makeToggleItem())
        m.addItem(.separator())

        let settingsItem = NSMenuItem(title: L10n.menuSettings,
                                      action: #selector(openSettings),
                                      keyEquivalent: ",")
        settingsItem.target = self
        m.addItem(settingsItem)

        let quitItem = NSMenuItem(title: L10n.menuQuit,
                                  action: #selector(quitApp),
                                  keyEquivalent: "q")
        quitItem.target = self
        m.addItem(quitItem)

        // [EN] Keep menu off statusItem — manual popUp after activation (see configureButton).
        // [CN] 不把 menu 挂到 statusItem —— 在 activate 后手动 popUp（见 configureButton）。
        // [JP] statusItem に menu を付けない — activate 後に手動 popUp（configureButton 参照）。
        menu = m
    }

    private func makeToggleItem() -> NSMenuItem {
        let item = NSMenuItem()
        let row = NSView(frame: NSRect(x: 0, y: 0, width: 220, height: 34))

        let label = NSTextField(labelWithString: L10n.menuToggle)
        label.font = .systemFont(ofSize: NSFont.systemFontSize)
        label.translatesAutoresizingMaskIntoConstraints = false

        let switchControl = NSSwitch()
        switchControl.state = isToggleOn ? .on : .off
        switchControl.isEnabled = true
        switchControl.target = self
        switchControl.action = #selector(toggleChanged(_:))
        switchControl.controlSize = .regular
        switchControl.translatesAutoresizingMaskIntoConstraints = false

        row.addSubview(label)
        row.addSubview(switchControl)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 16),
            label.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            switchControl.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -12),
            switchControl.centerYAnchor.constraint(equalTo: row.centerYAnchor)
        ])

        item.view = row
        toggleSwitch = switchControl
        return item
    }

    private func refreshToggleView() {
        guard let toggleSwitch else { return }
        toggleSwitch.isEnabled = true
        toggleSwitch.state = isToggleOn ? .on : .off
    }

    // MARK: - Actions

    @objc
    private func statusBarButtonClicked(_ sender: Any?) {
        guard statusItem?.button != nil, menu != nil else { return }

        NSApp.activate(ignoringOtherApps: true)

        // [EN] Defer popUp one run-loop turn so activation completes before menu tracking.
        // [CN] 推迟到下一 runloop 再 popUp，确保 activate 完成后再进入菜单追踪。
        // [JP] 1 runloop 遅延して popUp し、activate 完了後にメニュートラッキングを開始する。
        DispatchQueue.main.async { [weak self] in
            guard let self, let button = self.statusItem?.button, let menu = self.menu else { return }
            let anchor = self.menuPopUpAnchor(in: button)
            menu.popUp(positioning: nil, at: anchor, in: button)
        }
    }

    /// [EN] Responsive anchor for `NSMenu.popUp`: convert the status button into
    ///      screen space, place the anchor just below its bottom edge, then map back
    ///      into button coordinates. Works across resolutions, scale factors, and
    ///      notch / multi-monitor layouts without hard-coded view Y hacks.
    /// [CN] `NSMenu.popUp` 的响应式锚点：把状态栏按钮转换到屏幕坐标，在底边下方
    ///      放置锚点再映射回按钮坐标系，适配不同分辨率、缩放、刘海与多显示器。
    /// [JP] `NSMenu.popUp` 用のレスポンシブアンカー。ステータスボタンを
    ///      スクリーン座標へ変換し、下端の少し下に置いてからボタン座標へ戻す。
    private func menuPopUpAnchor(in button: NSStatusBarButton) -> NSPoint {
        guard let window = button.window else {
            return NSPoint(x: 0, y: 0)
        }

        let buttonInWindow = button.convert(button.bounds, to: nil)
        let buttonOnScreen = window.convertToScreen(buttonInWindow)

        var screenAnchor = NSPoint(
            x: buttonOnScreen.minX,
            y: buttonOnScreen.minY - Self.menuPopUpScreenGap
        )

        if let screen = window.screen {
            let visible = screen.visibleFrame
            let maxX = screenAnchor.x + Self.estimatedMenuWidth
            if maxX > visible.maxX {
                screenAnchor.x = max(visible.minX, visible.maxX - Self.estimatedMenuWidth)
            }
            screenAnchor.x = max(screenAnchor.x, visible.minX)
        }

        let anchorInWindow = window.convertPoint(fromScreen: screenAnchor)
        return button.convert(anchorInWindow, from: nil)
    }

    @objc
    private func toggleChanged(_ sender: NSSwitch) {
        isToggleOn = sender.state == .on
        refreshToggleView()
        onToggleChange?(isToggleOn)
    }

    @objc
    private func openSettings() {
        onSettingsRequested?()
    }

    @objc
    private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}

// MARK: - NSMenuDelegate

extension StatusBarController: NSMenuDelegate {

    func menuWillOpen(_ menu: NSMenu) {
        // [EN] Root-cause fix for the "first menu open shows gray switch track" bug.
        //
        //      NSSwitch reads `NSApp.isActive` when deciding whether to paint the
        //      `controlAccentColor` track (on, active) or the gray inactive track.
        //      For LSUIElement apps, clicking the status-bar item shows the menu
        //      but does NOT flip NSApp into the active state — so on first menu
        //      open the switch renders gray even though its state is `.on`.
        //      Opening the Settings window indirectly fixed it because
        //      `showAndFocus()` calls `NSApp.activate(...)`, and that activation
        //      persists. We activate explicitly here so the first menu open is
        //      already in the active context.
        //
        //      Note: AppDelegate also primes NSApp at launch, but a user may
        //      switch to another app and back; in that case NSApp can be inactive
        //      again. This call guarantees the menu is always in the active
        //      context regardless of what happened between opens.
        //
        // [CN] 首次打开菜单时开关轨迹呈灰色的根因修复。
        //
        //      NSSwitch 决定要画 `controlAccentColor` 轨迹（on/active）还是
        //      失效灰轨迹时，读取的是 `NSApp.isActive`。对 LSUIElement 应用，
        //      点击状态栏图标会弹菜单，但**不会**把 NSApp 切到 active —
        //      所以首次弹出时开关明明 `state = .on`，看上去却是灰的。
        //      之前打开设置窗口能间接修好，是因为 `showAndFocus()` 调了
        //      `NSApp.activate(...)`，而这个状态会延续。这里显式激活，
        //      保证菜单首次弹出就处在 active 上下文里。
        //
        //      注：AppDelegate 启动时也会 prime 一次 NSApp，但用户可能切到
        //      别的 app 再切回来，那时 NSApp 又会变成非 active。每次
        //      menuWillOpen 都激活一次，保证不论中间发生什么，菜单弹出时
        //      永远处于 active 上下文。
        //
        // [JP] 「メニュー初回オープン時にスイッチがグレー」バグの根本原因修正。
        //
        //      NSSwitch は `controlAccentColor` のトラック（on/active）と
        //      グレーの非アクティブトラックのどちらを描くかを決める際、
        //      `NSApp.isActive` を参照する。LSUIElement アプリでは
        //      ステータスバーアイコンクリックでメニューは表示されるが、
        //      NSApp は active にならない。そのため初回オープン時、
        //      `state = .on` でもスイッチがグレーで描画される。
        //      設定ウィンドウを開くと直る理由は `showAndFocus()` が
        //      `NSApp.activate(...)` を呼ぶためで、その状態は持続する。
        //      ここで明示的に activate することで、初回からアクティブな
        //      コンテキストでメニューを開けるようにする。
        //
        //      AppDelegate 起動時も prime しているが、ユーザーが他のアプリに
        //      切り替えて戻ると NSApp は再び非 active になりうる。毎回
        //      menuWillOpen で activate しておけば、間に何が起きても
        //      メニュー表示時は常に active コンテキストになる。
        NSApp.activate(ignoringOtherApps: true)

        isToggleOn = PreferencesStore.shared.isEnabled
        refreshToggleView()
    }
}
