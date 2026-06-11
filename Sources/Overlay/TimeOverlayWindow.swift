import Cocoa
import CoreGraphics

// ═══════════════════════════════════════════════════════════════
//  Overlay window — time flash that floats above everything
// ═══════════════════════════════════════════════════════════════
//
//  Architecture constraints enforced here (see 排雷指南):
//  • Zero-focus:   override canBecomeKey/canBecomeMain → false
//  • Mouse-passthrough: ignoresMouseEvents = true
//  • Topmost:      level = .screenSaverWindowLevel
//  • Spaces/Full-screen: canJoinAllSpaces + fullScreenAuxiliary
//  • Multi-screen: NSEvent.mouseLocation match, NSScreen.main as fallback
//
//  [EN] Phase 3 additions:
//       - 6-position coordinate calculation (Top-Left, Top, Top-Right,
//         Center, Bottom-Left, Bottom-Right)
//       - Duration read from UserDefaults in showAndFadeOut()
//  [CN] Phase 3 新增：
//       - 六种屏幕定位坐标计算（左上、顶端、右上、中央、左下、右下）
//       - showAndFadeOut() 从 UserDefaults 读取停留时间
//  [JP] Phase 3 追加：
//       - 6ポジションの座標計算（左上、上、右上、中央、左下、右下）
//       - showAndFadeOut() で UserDefaults から持続時間を読み取り
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

    private static let timeFormatter: DateFormatter = {
        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm"
        return fmt
    }()

    // ── Init ──────────────────────────────────────────────────

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

    // ── Dynamic screen positioning ────────────────────────────

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

        // [EN] Use visibleFrame to account for menu bar and Dock.
        // [CN] 使用 visibleFrame 以避开菜单栏和 Dock。
        // [JP] メニューバーとDockを考慮し visibleFrame を使用。
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

        // [EN] Default (and "Center") — centred both axes.
        // [CN] 默认及 "Center" —— 水平垂直居中。
        // [JP] デフォルト（"Center"）—— 縦横とも中央。
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

    // ── Show & Fade Out (with re-entrancy guard) ──────────────

    /// [EN] Animate: 0→1 (opacity), hold for user-configured duration (UserDefaults),
    ///      1→0 (opacity), then hide.
    ///      Re-entrancy guard prevents overlapping animations.
    /// [CN] 动画流程：透明度 0→1，停留用户设定的时长（来自 UserDefaults），
    ///      透明度 1→0，然后隐藏。
    ///      防重入守卫阻止动画重叠。
    /// [JP] アニメーション：不透明度 0→1、ユーザー設定の秒数停止（UserDefaults）、
    ///      不透明度 1→0、最後に非表示。
    ///      再入防止ガードによりアニメーションの重複を防止。
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

        contentView.updateTime(Self.timeFormatter.string(from: Date()))

        let holdDuration = PreferencesStore.shared.durationSeconds

        alphaValue = 0.0
        orderFront(nil)

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
                self.isAnimating = false
            }
        }

        // [EN] Safety release in case animation completion is dropped during sleep/screen changes.
        // [CN] 安全兜底：防止休眠或屏幕变化导致动画 completion 丢失后永久锁死。
        // [JP] スリープや画面変更で completion が失われた場合の安全解除。
        let timeout = TimeInterval(holdDuration) + Constants.fadeInDuration + Constants.fadeOutDuration + 1.0
        DispatchQueue.main.asyncAfter(deadline: .now() + timeout) { [weak self] in
            guard let self = self else { return }
            guard self.animationGeneration == generation else { return }
            self.isAnimating = false
        }
    }

    /// [EN] Show a persistent overlay for Settings live preview.
    /// [CN] 为设置页实时预览显示常驻弹窗。
    /// [JP] 設定画面のライブプレビュー用に常時表示する。
    func showPreview(configuration: OverlayConfiguration = OverlayConfiguration(preferences: PreferencesStore.shared)) {
        animationGeneration += 1
        isAnimating = false

        guard let contentView = self.contentView as? TimeOverlayView else { return }
        applyAppearance(configuration, to: contentView)
        contentView.updateTime(Self.timeFormatter.string(from: Date()))
        positionOnActiveScreen(position: configuration.position,
                               fontScale: configuration.fontScale)

        alphaValue = 1.0
        orderFront(nil)
    }

    /// [EN] Immediately hide the overlay and invalidate pending animation callbacks.
    /// [CN] 立即隐藏弹窗，并使尚未执行的动画回调失效。
    /// [JP] オーバーレイを即座に隠し、保留中のアニメーションコールバックを無効化。
    func hideImmediately() {
        animationGeneration += 1
        isAnimating = false
        alphaValue = 0.0
        orderOut(nil)
    }

    private func applyAppearance(_ configuration: OverlayConfiguration, to contentView: TimeOverlayView) {
        let scale = configuration.fontScale.multiplier
        let opacity = CGFloat(configuration.backgroundOpacity)
        contentView.applyAppearance(fontScale: scale, backgroundOpacity: opacity)
    }
}

// ═══════════════════════════════════════════════════════════════
//  Content view — large soft-coloured time string on a
//  semi-transparent rounded-rect background
// ═══════════════════════════════════════════════════════════════

private final class TimeOverlayView: NSView {

    private let timeLabel: NSTextField = {
        let l = NSTextField(labelWithString: "")
        // [EN] Large, bold system font for maximum readability at a glance.
        // [CN] 大号粗体系统字体，一瞥即可辨认。
        // [JP] 一目で読めるよう太字・大サイズのシステムフォント。
        l.font = NSFont.monospacedDigitSystemFont(ofSize: Constants.timeFontSize,
                                                   weight: .bold)
        // [EN] Soft pastel cream colour — easier on the eyes than pure white.
        // [CN] 柔和的暖白色（奶油色），比纯白更护眼。
        // [JP] やわらかなクリーム色。純白より目に優しい。
        l.textColor = NSColor(calibratedWhite: 0.92, alpha: 1.0)
        l.alignment = .center
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    // ── Init ──────────────────────────────────────────────────

    override init(frame: NSRect) {
        super.init(frame: frame)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        wantsLayer = true
        // [EN] Dark, slightly transparent background — visible on any screen content.
        // [CN] 深色半透明背景——任何屏幕内容上都可见。
        // [JP] 暗めの半透明背景 — どのような画面コンテンツの上でも視認可能。
        layer?.backgroundColor = NSColor.black.withAlphaComponent(0.55).cgColor
        layer?.cornerRadius = 28

        addSubview(timeLabel)
        NSLayoutConstraint.activate([
            timeLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            timeLabel.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    // ── API ───────────────────────────────────────────────────

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
