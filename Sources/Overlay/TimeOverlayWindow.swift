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
//  • Multi-screen: positionOnActiveScreen() called before every flash
// ═══════════════════════════════════════════════════════════════

final class TimeOverlayWindow: NSWindow {

    // ═══ 排雷指南: 零焦点抢夺 ═══
    override var canBecomeKey: Bool  { false }
    override var canBecomeMain: Bool { false }

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

        // ── Content view ──────────────────────────────────────
        contentView = TimeOverlayView(frame: contentRect(forFrameRect: frame))
    }

    // ── Dynamic screen positioning ────────────────────────────

    /// Reposition the window on the active screen BEFORE each flash.
    /// This handles hot-plugged displays and cursor-moved-to-another-screen.
    func positionOnActiveScreen() {
        let screen = bestTargetScreen()
        guard let s = screen else { return }

        let sf = s.frame
        let x = sf.origin.x + (sf.width  - Constants.overlayWidth)  / 2
        let y = sf.origin.y + (sf.height - Constants.overlayHeight) / 2

        setFrame(NSRect(x: x, y: y,
                        width: Constants.overlayWidth,
                        height: Constants.overlayHeight),
                 display: false)
    }

    /// Prefer the screen containing the mouse cursor; fall back to main.
    private func bestTargetScreen() -> NSScreen? {
        let mousePt = NSEvent.mouseLocation   // no AX permission needed
        if let hit = NSScreen.screens.first(where: { $0.frame.contains(mousePt) }) {
            return hit
        }
        return NSScreen.main
    }

    // ── Flash ─────────────────────────────────────────────────

    /// Show the current time and auto-dismiss after `flashDuration`.
    func flashCurrentTime() {
        guard let contentView = self.contentView as? TimeOverlayView else { return }

        // Update time string
        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm:ss"
        contentView.updateTime(fmt.string(from: Date()))

        // Reset alpha & show (in case a previous fade left alpha = 0)
        alphaValue = 1.0
        orderFront(nil)

        // Schedule fade-out after flash duration
        DispatchQueue.main.asyncAfter(deadline: .now() + Constants.flashDuration) { [weak self] in
            guard let self = self else { return }

            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = Constants.fadeOutDuration
                ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
                self.animator().alphaValue = 0.0
            } completionHandler: { [weak self] in
                self?.orderOut(nil)
            }
        }
    }
}

// ═══════════════════════════════════════════════════════════════
//  Content view — large white time string on a semi-transparent
//  rounded-rect background
// ═══════════════════════════════════════════════════════════════

private final class TimeOverlayView: NSView {

    private let timeLabel: NSTextField = {
        let l = NSTextField(labelWithString: "")
        l.font = NSFont.monospacedDigitSystemFont(ofSize: Constants.timeFontSize,
                                                   weight: .regular)
        l.textColor = NSColor.white
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
        layer?.backgroundColor = NSColor.black.withAlphaComponent(0.65).cgColor
        layer?.cornerRadius = 24

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
