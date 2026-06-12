import Cocoa

// ═══════════════════════════════════════════════════════════════
//  StatusBarController — menu bar surface
// ═══════════════════════════════════════════════════════════════
//
//  [EN] LSUIElement apps need a reliable menu-bar exit path.
//       The menu stays deliberately small: Toggle, Settings..., Quit.
//
//  [CN] LSUIElement 应用必须保留可靠的菜单栏退出入口。
//       菜单保持克制：开关、设置、退出。
//
//  [JP] LSUIElement アプリには確実な終了導線が必要。
//       メニューは「切替、設定、終了」に絞る。
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

    // MARK: - 属性

    private var statusItem: NSStatusItem?
    private var menu: NSMenu?
    private weak var toggleSwitch: NSSwitch?
    private var isToggleOn = PreferencesStore.shared.isEnabled

    var onToggleChange: ((Bool) -> Void)?
    var onSettingsRequested: (() -> Void)?

    // MARK: - 初始化

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

    // MARK: - 对外接口

    func updateToggle(isOn: Bool) {
        isToggleOn = isOn
        refreshToggleView()
    }

    // MARK: - 状态栏按钮

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

    // MARK: - 菜单

    // 构建菜单内容；菜单不直接挂到 statusItem，避免首次点击时被 AppKit 提前弹出。
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

    // 使用自定义 view 承载开关，保证菜单内可直接切换提醒状态。
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

    // 将模型状态同步到当前可见的 NSSwitch。
    private func refreshToggleView() {
        guard let toggleSwitch else { return }
        toggleSwitch.isEnabled = true
        toggleSwitch.state = isToggleOn ? .on : .off
    }

    // MARK: - 动作

    // 菜单栏图标点击时先激活 App，再手动弹出菜单。
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

    // NSSwitch 状态变化后通知外层协调者处理业务状态。
    @objc
    private func toggleChanged(_ sender: NSSwitch) {
        isToggleOn = sender.state == .on
        refreshToggleView()
        onToggleChange?(isToggleOn)
    }

    // 转发设置窗口打开请求，具体窗口生命周期由上层管理。
    @objc
    private func openSettings() {
        onSettingsRequested?()
    }

    // 退出 LSUIElement 应用的明确入口。
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

        NSApp.activate(ignoringOtherApps: true)

        isToggleOn = PreferencesStore.shared.isEnabled
        refreshToggleView()
    }
}
