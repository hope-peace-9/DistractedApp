import Foundation
import CoreGraphics

// ═══════════════════════════════════════════════════════════════
//  Centralised constants — single source of truth for tuning.
//  [EN] Tweak these values to adjust behaviour without touching logic.
//  [CN] 调参集中地，不动逻辑即可修改行为。
//  [JP] 動作を変更するにはここだけ編集すればOK。
// ═══════════════════════════════════════════════════════════════

enum Constants {

    static let appVersion = "1.0.0"

    // MARK: - 计时器
    /// [EN] Default interval between time flashes (seconds).  UserDefaults overrides.
    /// [CN] 默认闪烁间隔（秒）。UserDefaults 优先级更高。
    /// [JP] デフォルトの点滅間隔（秒）。UserDefaultsが優先。
    static let defaultFlashInterval: TimeInterval = 1800  // 30 分钟
    static let defaultIntervalMinutes: Int = 30
    static let intervalMinMinutes: Int = 1
    static let intervalMaxMinutes: Int = 999

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

    // MARK: - 窗口几何
    static let overlayWidth: CGFloat  = 520
    static let overlayHeight: CGFloat = 260

    /// [EN] Inset from screen edges for corner / side positioning.
    /// [CN] 角/边定位时距离屏幕边缘的内边距。
    /// [JP] 隅・端に配置するときの画面端からの余白。
    static let positionInset: CGFloat = 40

    static let defaultDurationSeconds: Int = 2
    static let durationMin: Int = 1
    static let durationMax: Int = 10

    // MARK: - 视觉默认值
    static let defaultBackgroundOpacity: Double = 0.5
    static let backgroundOpacityMin: Double = 0.0
    static let backgroundOpacityMax: Double = 1.0

    // MARK: - UserDefaults 键
    /// [EN] Keys used to persist user preferences in NSUserDefaults.
    /// [CN] 持久化用户偏好时使用的 NSUserDefaults 键名。
    /// [JP] ユーザー設定を NSUserDefaults に保存するためのキー。
    enum UserDefaultsKey {
        /// 用户面向的提醒开关。
        static let isEnabled = "isEnabled"
        /// 闪烁间隔，单位为分钟。
        static let intervalMinutes = "intervalMinutes"
        /// 屏幕位置预设。
        static let position = "position"
        /// 弹窗停留时间，单位为秒。
        static let durationSeconds = "durationSeconds"
        /// 悬浮窗字体与背景缩放预设。
        static let fontScale = "fontScale"
        /// 悬浮窗背景透明度，范围为 0.0...1.0。
        static let backgroundOpacity = "backgroundOpacity"
        /// 偏好结构版本，用于未来迁移。
        static let schemaVersion = "schemaVersion"
        /// 是否不再显示登录启动引导弹窗。
        static let hasPromptedForStartup = "hasPromptedForStartup"
    }

    // MARK: - 历史迁移位置
    enum LegacyPosition: String, CaseIterable {
        case topLeft     = "Top-Left"
        case top         = "Top"
        case topRight    = "Top-Right"
        case center      = "Center"
        case bottomLeft  = "Bottom-Left"
        case bottomRight = "Bottom-Right"
    }

    // MARK: - 悬浮窗位置
    enum OverlayPosition: String, CaseIterable {
        case topLeft = "Top-Left"
        case topCenter = "Top"
        case topRight = "Top-Right"
        case middleLeft = "Middle-Left"
        case center = "Center"
        case middleRight = "Middle-Right"
        case bottomLeft = "Bottom-Left"
        case bottomCenter = "Bottom"
        case bottomRight = "Bottom-Right"
    }

    enum FontScale: String, CaseIterable {
        case small
        case medium
        case large

        var multiplier: CGFloat {
            switch self {
            case .small:
                return 0.75
            case .medium:
                return 1.0
            case .large:
                return 1.5
            }
        }
    }
}
