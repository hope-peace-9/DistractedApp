import Foundation
import CoreGraphics

// ═══════════════════════════════════════════════════════════════
//  Centralised constants — single source of truth for tuning.
//  [EN] Tweak these values to adjust behaviour without touching logic.
//  [CN] 调参集中地，不动逻辑即可修改行为。
//  [JP] 動作を変更するにはここだけ編集すればOK。
// ═══════════════════════════════════════════════════════════════

enum Constants {

    // ── Timer ──────────────────────────────────────────────────
    /// [EN] Default interval between time flashes (seconds).  UserDefaults overrides.
    /// [CN] 默认闪烁间隔（秒）。UserDefaults 优先级更高。
    /// [JP] デフォルトの点滅間隔（秒）。UserDefaultsが優先。
    static let defaultFlashInterval: TimeInterval = 1800  // 30 min

    // ── Overlay display ────────────────────────────────────────
    /// [EN] How long the time stays fully visible before fade-out.
    /// [CN] 时间文字保持完全可见的时间（秒），之后开始淡出。
    /// [JP] 完全表示の持続時間（秒）。その後フェードアウト開始。
    static let flashDuration: TimeInterval = 2.0

    /// [EN] Duration of the fade-in animation at the start of a flash.
    /// [CN] 淡入动画持续时间。
    /// [JP] フェードインの所要時間。
    static let fadeInDuration: TimeInterval = 0.15

    /// [EN] Duration of the fade-out animation.
    /// [CN] 淡出动画持续时间。
    /// [JP] フェードアウトの所要時間。
    static let fadeOutDuration: TimeInterval = 0.5

    /// [EN] Font size of the time digits.
    /// [CN] 时间数字的字体大小。
    /// [JP] 時刻フォントのサイズ。
    static let timeFontSize: CGFloat = 140

    // ── Window geometry ────────────────────────────────────────
    static let overlayWidth: CGFloat  = 520
    static let overlayHeight: CGFloat = 260

    /// [EN] Inset from screen edges for corner / side positioning.
    /// [CN] 角/边定位时距离屏幕边缘的内边距。
    /// [JP] 隅・端に配置するときの画面端からの余白。
    static let positionInset: CGFloat = 40

    /// [EN] Offset from top edge when position = "Top" (redundant with positionInset now, kept for backward compat).
    /// [CN] 当 position = "Top" 时距离屏幕顶部的偏移（现与 positionInset 冗余，保留向后兼容）。
    /// [JP] position = "Top" のときの画面上端からのオフセット（現在はpositionInsetと重複、後方互換用）。
    static let topPositionOffset: CGFloat = 80

    // ── Duration presets ───────────────────────────────────────
    /// [EN] Preset duration values (seconds) shown in the Duration submenu.
    /// [CN] 停留时间子菜单中显示的预设值（秒）。
    /// [JP] 持続時間サブメニューに表示するプリセット値（秒）。
    static let durationPresets: [Int] = [2, 5]
    static let defaultDurationSeconds: Int = 2
    static let durationMin: Int = 1
    static let durationMax: Int = 10

    // ── Interval presets ───────────────────────────────────────
    /// [EN] Preset interval values (minutes) shown in the Interval submenu.
    /// [CN] 间隔子菜单中显示的预设值（分钟）。
    /// [JP] 間隔サブメニューに表示するプリセット値（分）。
    static let intervalPresets: [Int] = [15, 30, 60, 120]

    // ── UserDefaults keys ──────────────────────────────────────
    /// [EN] Keys used to persist user preferences in NSUserDefaults.
    /// [CN] 持久化用户偏好时使用的 NSUserDefaults 键名。
    /// [JP] ユーザー設定を NSUserDefaults に保存するためのキー。
    enum UserDefaultsKey {
        /// [EN] Flash interval in minutes (Double).
        static let intervalMinutes = "intervalMinutes"
        /// [EN] Screen position preset.
        static let position = "position"
        /// [EN] Display hold duration in seconds (Int).
        static let durationSeconds = "durationSeconds"
    }

    // ── Position options ───────────────────────────────────────
    /// [EN] Available screen-position presets shown in the menu.
    /// [CN] 菜单位置预设的可选值。
    /// [JP] メニューで選択可能な画面位置のプリセット。
    enum Position: String, CaseIterable {
        case topLeft     = "Top-Left"
        case top         = "Top"
        case topRight    = "Top-Right"
        case center      = "Center"
        case bottomLeft  = "Bottom-Left"
        case bottomRight = "Bottom-Right"
    }
}
