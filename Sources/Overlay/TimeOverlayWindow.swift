import Cocoa
import CoreGraphics

// ═══════════════════════════════════════════════════════════════
//  TimeOverlayWindow — 悬浮时钟窗口 / フローティング時刻ウィンドウ
// ═══════════════════════════════════════════════════════════════
//
//  [EN] Presents the floating time overlay, keeps it above all spaces,
//       and refreshes the displayed clock independently from UI tracking.
//  [CN] 负责显示悬浮时间窗口，使其覆盖所有桌面空间，并让时间显示脱离 UI 事件追踪独立刷新。
//  [JP] フローティング時刻ウィンドウを表示し、すべてのスペース上に維持しつつ、
//       UI イベント追跡とは独立して時刻表示を更新する。
// ═══════════════════════════════════════════════════════════════

final class TimeOverlayWindow: NSWindow {

    // ═══ 排雷指南: 零焦点抢夺 ═══
    override var canBecomeKey: Bool  { false }
    override var canBecomeMain: Bool { false }

    /// [EN] Re-entrancy guard: skip if animation is already in progress.
    /// [CN] 防重入守卫：动画进行中忽略一切新触发。
    /// [JP] 再入防止フラグ：アニメーション中は新規呼び出しを無視。
    private var isAnimating = false
    private var animationGeneration = 0
    /// 显示时间与提醒调度解耦，避免设置预览期间 UI 事件追踪冻结时钟显示。
    private var clockTimer: DispatchSourceTimer?
    private let clockQueue = DispatchQueue(label: "com.distracted.overlay.clock",
                                           qos: .utility)

    private static let timeFormatter: DateFormatter = {
        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm"
        return fmt
    }()

    // MARK: - 初始化

    init() {
        let frame = NSRect(x: 0, y: 0,
                           width: Constants.overlayWidth,
                           height: Constants.overlayHeight)

        super.init(contentRect: frame,
                   styleMask: [.borderless],
                   backing: .buffered,
                   defer: false)

        isReleasedWhenClosed = false
        isOpaque = false
        hasShadow = false
        backgroundColor = .clear

        // ═══ 排雷指南: 绝对鼠标穿透 ═══
        ignoresMouseEvents = true

        // ═══ 排雷指南: 全屏穿透 & 多桌面 ═══
        level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.screenSaverWindow)))
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        contentView = TimeOverlayView(frame: contentRect(forFrameRect: frame))
    }

    deinit {
        stopClockUpdates()
    }

    // MARK: - 屏幕定位

    /// [EN] Position the window based on the active screen and user preference.
    ///      Supports 6 presets: Top-Left, Top, Top-Right, Center, Bottom-Left, Bottom-Right.
    ///      Uses the **mouse cursor's screen** as priority; NSScreen.main as fallback.
    /// [CN] 根据当前活跃屏幕和用户偏好定位窗口。
    ///      支持 6 种预设：左上、顶端、右上、中央、左下、右下。
    ///      优先使用鼠标光标所在屏幕；兜底用主屏。
    /// [JP] アクティブスクリーンとユーザー設定に基づきウィンドウを配置。
    ///      6つのプリセットに対応：左上、上、右上、中央、左下、右下。
    ///      マウスカーソルがある画面を優先、なければメイン画面。
    ///
    /// - Parameter position: One of the Constants.OverlayPosition raw values.
    func positionOnActiveScreen(position: String = Constants.OverlayPosition.center.rawValue) {
        let normalized = Constants.OverlayPosition(rawValue: position) ?? .center
        positionOnActiveScreen(position: normalized,
                               fontScale: PreferencesStore.shared.fontScale)
    }

    private func positionOnActiveScreen(position: Constants.OverlayPosition,
                                        fontScale: Constants.FontScale) {
        guard let screen = bestTargetScreen() else { return }

        // 使用 visibleFrame，确保贴边位置避开菜单栏和 Dock。
        let sf = screen.visibleFrame
        let scale = fontScale.multiplier
        let w = Constants.overlayWidth * scale
        let h = Constants.overlayHeight * scale
        let inset = Constants.positionInset

        let originX: CGFloat
        let originY: CGFloat

        switch position {
        case .topLeft:
            originX = sf.origin.x + inset
            originY = sf.origin.y + sf.height - h - inset

        case .topCenter:
            originX = sf.origin.x + (sf.width - w) / 2
            originY = sf.origin.y + sf.height - h - inset

        case .topRight:
            originX = sf.origin.x + sf.width - w - inset
            originY = sf.origin.y + sf.height - h - inset

        case .middleLeft:
            originX = sf.origin.x + inset
            originY = sf.origin.y + (sf.height - h) / 2

        case .middleRight:
            originX = sf.origin.x + sf.width - w - inset
            originY = sf.origin.y + (sf.height - h) / 2

        case .bottomLeft:
            originX = sf.origin.x + inset
            originY = sf.origin.y + inset

        case .bottomCenter:
            originX = sf.origin.x + (sf.width - w) / 2
            originY = sf.origin.y + inset

        case .bottomRight:
            originX = sf.origin.x + sf.width - w - inset
            originY = sf.origin.y + inset

        case .center:
            originX = sf.origin.x + (sf.width - w) / 2
            originY = sf.origin.y + (sf.height - h) / 2
        }

        setFrame(NSRect(x: originX, y: originY, width: w, height: h), display: false)
    }

    /// [EN] Prefer the screen containing the mouse cursor; fall back to main.
    /// [CN] 优先选择鼠标光标所在的屏幕；兜底用主屏。
    /// [JP] マウスカーソルがある画面を優先、なければメイン画面。
    private func bestTargetScreen() -> NSScreen? {
        let mousePt = NSEvent.mouseLocation
        if let hit = NSScreen.screens.first(where: { $0.frame.contains(mousePt) }) {
            return hit
        }
        return NSScreen.main
    }

    // MARK: - 显示与隐藏

    /// 显示一次短暂提醒，并在配置的停留时间后隐藏；重叠触发会被忽略以保持视觉稳定。
    func showAndFadeOut() {
        guard !isAnimating else {
            print("[Distracted] showAndFadeOut skipped — animation in progress")
            return
        }
        isAnimating = true
        animationGeneration += 1
        let generation = animationGeneration

        guard let contentView = self.contentView as? TimeOverlayView else {
            isAnimating = false
            return
        }

        let configuration = OverlayConfiguration(preferences: PreferencesStore.shared)
        applyAppearance(configuration, to: contentView)

        positionOnActiveScreen(position: configuration.position,
                               fontScale: configuration.fontScale)

        let holdDuration = PreferencesStore.shared.durationSeconds

        alphaValue = 0.0
        orderFront(nil)
        startClockUpdates(generation: generation)

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = Constants.fadeInDuration
            ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
            self.animator().alphaValue = 1.0
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + TimeInterval(holdDuration)) { [weak self] in
            guard let self = self else { return }
            guard self.animationGeneration == generation else { return }

            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = Constants.fadeOutDuration
                ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
                self.animator().alphaValue = 0.0
            } completionHandler: { [weak self] in
                guard let self = self else { return }
                guard self.animationGeneration == generation else { return }
                self.orderOut(nil)
                self.stopClockUpdates()
                self.isAnimating = false
            }
        }

        // 休眠或屏幕变化可能导致 AppKit 丢失动画完成回调，这里兜底释放动画状态。
        let timeout = TimeInterval(holdDuration) + Constants.fadeInDuration + Constants.fadeOutDuration + 1.0
        DispatchQueue.main.asyncAfter(deadline: .now() + timeout) { [weak self] in
            guard let self = self else { return }
            guard self.animationGeneration == generation else { return }
            self.stopClockUpdates()
            self.isAnimating = false
        }
    }

    /// 显示设置页实时预览使用的常驻悬浮窗。
    func showPreview(configuration: OverlayConfiguration = OverlayConfiguration(preferences: PreferencesStore.shared)) {
        animationGeneration += 1
        isAnimating = false

        guard let contentView = self.contentView as? TimeOverlayView else { return }
        applyAppearance(configuration, to: contentView)
        positionOnActiveScreen(position: configuration.position,
                               fontScale: configuration.fontScale)

        alphaValue = 1.0
        orderFront(nil)
        startClockUpdates(generation: animationGeneration)
    }

    /// 立即隐藏悬浮窗，并使尚未执行的动画回调失效。
    func hideImmediately() {
        animationGeneration += 1
        isAnimating = false
        alphaValue = 0.0
        orderOut(nil)
        stopClockUpdates()
    }

    // 将草稿或偏好配置映射到具体视图外观，避免窗口层关心控件细节。
    private func applyAppearance(_ configuration: OverlayConfiguration, to contentView: TimeOverlayView) {
        let scale = configuration.fontScale.multiplier
        let opacity = CGFloat(configuration.backgroundOpacity)
        contentView.applyAppearance(fontScale: scale, backgroundOpacity: opacity)
    }

    // 使用 GCD 计时器独立刷新当前时间，避免 RunLoop 菜单追踪或模态窗口影响显示。
    private func startClockUpdates(generation: Int) {
        stopClockUpdates()
        refreshDisplayedTime()

        let timer = DispatchSource.makeTimerSource(queue: clockQueue)
        timer.schedule(deadline: .now() + 1, repeating: 1, leeway: .milliseconds(100))
        timer.setEventHandler { [weak self] in
            DispatchQueue.main.async {
                guard let self else { return }
                guard self.animationGeneration == generation else { return }
                self.refreshDisplayedTime()
            }
        }
        timer.resume()
        clockTimer = timer
    }

    // 停止并释放当前显示计时器，避免悬浮窗隐藏后继续回调主线程。
    private func stopClockUpdates() {
        clockTimer?.setEventHandler {}
        clockTimer?.cancel()
        clockTimer = nil
    }

    // 统一从系统当前时间生成显示文案，保证预览与提醒窗口使用同一时间来源。
    private func refreshDisplayedTime() {
        guard let contentView = self.contentView as? TimeOverlayView else { return }
        contentView.updateTime(Self.timeFormatter.string(from: Date()))
    }
}

// ═══════════════════════════════════════════════════════════════
//  TimeOverlayView — clock label and rounded background drawing
// ═══════════════════════════════════════════════════════════════
//
//  [CN] 只负责绘制时间文字和半透明圆角背景，窗口层负责定位、显示和计时。
// ═══════════════════════════════════════════════════════════════

private final class TimeOverlayView: NSView {

    private let timeLabel: NSTextField = {
        let l = NSTextField(labelWithString: "")
        l.font = NSFont.monospacedDigitSystemFont(ofSize: Constants.timeFontSize,
                                                   weight: .bold)
        l.textColor = NSColor(calibratedWhite: 0.92, alpha: 1.0)
        l.alignment = .center
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    // MARK: - 初始化

    override init(frame: NSRect) {
        super.init(frame: frame)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    // 统一初始化 layer 与约束，保证代码路径和 nib 初始化路径一致。
    private func commonInit() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.withAlphaComponent(0.55).cgColor
        layer?.cornerRadius = 28

        addSubview(timeLabel)
        NSLayoutConstraint.activate([
            timeLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            timeLabel.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    // MARK: - 对外接口

    func updateTime(_ string: String) {
        timeLabel.stringValue = string
    }

    func applyAppearance(fontScale: CGFloat, backgroundOpacity: CGFloat) {
        timeLabel.font = NSFont.monospacedDigitSystemFont(ofSize: Constants.timeFontSize * fontScale,
                                                          weight: .bold)
        layer?.backgroundColor = NSColor.black.withAlphaComponent(backgroundOpacity).cgColor
        layer?.cornerRadius = 28 * fontScale
    }
}
