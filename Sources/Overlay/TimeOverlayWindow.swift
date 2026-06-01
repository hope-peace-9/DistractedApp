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
//  [EN] Phase 2 additions:
//       - showAndFadeOut() with re-entrancy guard
//       - Position-based coordinate calculation (Center / Top)
//       - Soft pastel text colour, HH:mm format, fade-in + hold + fade-out
//  [CN] Phase 2 新增：
//       - showAndFadeOut() 防重入保护
//       - 基于 position 的坐标计算（Center / Top）
//       - 柔和配色，HH:mm 格式，淡入 + 停留 + 淡出
//  [JP] Phase 2 追加：
//       - 再入防止付き showAndFadeOut()
//       - position（Center/Top）に基づく座標計算
//       - ソフトな色合い、HH:mm 形式、フェードイン→停止→フェードアウト
// ═══════════════════════════════════════════════════════════════

final class TimeOverlayWindow: NSWindow {

    // ═══ 排雷指南: 零焦点抢夺 ═══
    override var canBecomeKey: Bool  { false }
    override var canBecomeMain: Bool { false }

    // [EN] Re-entrancy guard: skip if animation is already in progress.
    // [CN] 防重入守卫：动画进行中忽略一切新触发。
    // [JP] 再入防止フラグ：アニメーション中は新規呼び出しを無視。
    private var isAnimating = false

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
    /// [CN] 根据当前活跃屏幕和用户偏好定位窗口。
    /// [JP] アクティブスクリーンとユーザー設定に基づきウィンドウを配置。
    ///
    /// - Parameter position: "Center" (screen centre) or "Top" (top-centre).
    func positionOnActiveScreen(position: String = "Center") {
        guard let screen = bestTargetScreen() else { return }

        let sf = screen.visibleFrame
        let w = Constants.overlayWidth
        let h = Constants.overlayHeight

        let centerX = sf.origin.x + (sf.width - w) / 2

        let originY: CGFloat
        if position == "Top" {
            // [EN] Pin near the top edge of the screen.
            // [CN] 将窗口固定在屏幕靠上的位置。
            // [JP] 画面上端付近にウィンドウを固定。
            originY = sf.origin.y + sf.height - h - Constants.topPositionOffset
        } else {
            // [EN] Default: vertical centre.
            // [CN] 默认：垂直居中。
            // [JP] デフォルト：垂直中央。
            originY = sf.origin.y + (sf.height - h) / 2
        }

        setFrame(NSRect(x: centerX, y: originY, width: w, height: h), display: false)
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

    /// [EN] Animate: 0→1 (opacity), hold 2s, 1→0 (opacity), then hide.
    ///      Re-entrancy guard prevents overlapping animations.
    /// [CN] 动画流程：透明度 0→1，停留 2 秒，透明度 1→0，然后隐藏。
    ///      防重入守卫阻止动画重叠。
    /// [JP] アニメーション：不透明度 0→1、2秒停止、1→0、最後に非表示。
    ///      再入防止ガードによりアニメーションの重複を防止。
    func showAndFadeOut() {
        // [EN] Re-entrancy guard: if already animating, ignore this call.
        // [CN] 防重入：如果动画正在进行，忽略本次调用。
        // [JP] 再入防止：アニメーション中はこの呼び出しを無視。
        guard !isAnimating else {
            print("[Distracted] showAndFadeOut skipped — animation in progress")
            return
        }
        isAnimating = true

        guard let contentView = self.contentView as? TimeOverlayView else {
            isAnimating = false
            return
        }

        // [EN] Read user's position preference from UserDefaults.
        // [CN] 从 UserDefaults 读取用户位置偏好。
        // [JP] UserDefaults から位置設定を読み込む。
        let position = UserDefaults.standard.string(forKey: Constants.UserDefaultsKey.position)
                       ?? Constants.Position.center.rawValue
        positionOnActiveScreen(position: position)

        // [EN] Update time string (HH:mm format — concise, glanceable).
        // [CN] 更新时间字符串（HH:mm 格式 — 简洁、一目了然）。
        // [JP] 時刻文字列を更新（HH:mm 形式 — 簡潔で一目瞭然）。
        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm"
        contentView.updateTime(fmt.string(from: Date()))

        // [EN] Ensure window starts invisible before fade-in.
        // [CN] 确保窗口在淡入前初始为不可见。
        // [JP] フェードイン前にウィンドウを確実に非表示に。
        alphaValue = 0.0
        orderFront(nil)

        // ── Phase 1: Fade in ──────────────────────────────────
        // [EN] Animate alpha from 0 → 1.
        // [CN] 透明度从 0 动画过渡到 1。
        // [JP] 不透明度を 0 → 1 にアニメーション。
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = Constants.fadeInDuration
            ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
            self.animator().alphaValue = 1.0
        }

        // ── Phase 2: Hold → Fade out ─────────────────────────
        // [EN] After the hold duration, animate alpha from 1 → 0, then hide.
        // [CN] 停留时间结束后，透明度从 1 动画过渡到 0，然后隐藏。
        // [JP] 停止時間経過後、不透明度を 1 → 0 にアニメーションし非表示に。
        DispatchQueue.main.asyncAfter(deadline: .now() + Constants.flashDuration) { [weak self] in
            guard let self = self else { return }

            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = Constants.fadeOutDuration
                ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
                self.animator().alphaValue = 0.0
            } completionHandler: { [weak self] in
                guard let self = self else { return }
                self.orderOut(nil)
                // [EN] Release re-entrancy guard.
                // [CN] 释放防重入锁。
                // [JP] 再入防止フラグを解放。
                self.isAnimating = false
            }
        }
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
}
