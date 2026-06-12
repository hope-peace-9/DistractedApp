import Foundation

// ═══════════════════════════════════════════════════════════════
//  PreferencesStore — typed UserDefaults gateway
// ═══════════════════════════════════════════════════════════════
//
//  [EN] Responsibilities:
//       1. Centralise all UserDefaults keys and fallback values.
//       2. Clamp persisted values into supported product ranges.
//       3. Keep legacy raw values readable across preference migrations.
//
//  [CN] 职责：
//       1. 集中管理全部 UserDefaults 键与默认值。
//       2. 将持久化数据限制在当前产品支持的合法范围内。
//       3. 在偏好迁移期间兼容历史 raw value。
//
//  [JP] 責務：
//       1. UserDefaults のキーと既定値を一元管理。
//       2. 保存値を現在サポートする範囲に丸める。
//       3. 設定移行時も旧 raw value を読み取れるようにする。
// ═══════════════════════════════════════════════════════════════

final class PreferencesStore {

    // MARK: - 单例

    static let shared = PreferencesStore()

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        ensureSchemaVersion()
    }

    // MARK: - 提醒开关

    var isEnabled: Bool {
        get {
            if defaults.object(forKey: Constants.UserDefaultsKey.isEnabled) == nil {
                return true
            }
            return defaults.bool(forKey: Constants.UserDefaultsKey.isEnabled)
        }
        set {
            defaults.set(newValue, forKey: Constants.UserDefaultsKey.isEnabled)
        }
    }

    // MARK: - 提醒间隔

    var intervalMinutes: Int {
        get {
            let stored = defaults.integer(forKey: Constants.UserDefaultsKey.intervalMinutes)
            return Self.clamp(stored,
                              min: Constants.intervalMinMinutes,
                              max: Constants.intervalMaxMinutes,
                              fallback: Constants.defaultIntervalMinutes)
        }
        set {
            defaults.set(Self.clamp(newValue,
                                    min: Constants.intervalMinMinutes,
                                    max: Constants.intervalMaxMinutes,
                                    fallback: Constants.defaultIntervalMinutes),
                         forKey: Constants.UserDefaultsKey.intervalMinutes)
        }
    }

    var intervalSeconds: TimeInterval {
        TimeInterval(intervalMinutes * 60)
    }

    // MARK: - 停留时间

    var durationSeconds: Int {
        get {
            let stored = defaults.integer(forKey: Constants.UserDefaultsKey.durationSeconds)
            return Self.clamp(stored,
                              min: Constants.durationMin,
                              max: Constants.durationMax,
                              fallback: Constants.defaultDurationSeconds)
        }
        set {
            defaults.set(Self.clamp(newValue,
                                    min: Constants.durationMin,
                                    max: Constants.durationMax,
                                    fallback: Constants.defaultDurationSeconds),
                         forKey: Constants.UserDefaultsKey.durationSeconds)
        }
    }

    // MARK: - 显示位置

    var overlayPosition: Constants.OverlayPosition {
        get {
            let raw = defaults.string(forKey: Constants.UserDefaultsKey.position)
            return Self.normalizedPosition(from: raw)
        }
        set {
            defaults.set(newValue.rawValue, forKey: Constants.UserDefaultsKey.position)
        }
    }

    /// [EN] Raw-value bridge for legacy callers and persisted settings.
    /// [CN] 兼容历史调用方和已持久化设置的 raw value 桥接。
    /// [JP] 旧呼び出し元と保存済み設定のための raw value ブリッジ。
    var overlayPositionRawValue: String {
        overlayPosition.rawValue
    }

    // MARK: - 视觉设置

    var fontScale: Constants.FontScale {
        get {
            let raw = defaults.string(forKey: Constants.UserDefaultsKey.fontScale)
            return raw.flatMap(Constants.FontScale.init(rawValue:)) ?? .medium
        }
        set {
            defaults.set(newValue.rawValue, forKey: Constants.UserDefaultsKey.fontScale)
        }
    }

    var backgroundOpacity: Double {
        get {
            if defaults.object(forKey: Constants.UserDefaultsKey.backgroundOpacity) == nil {
                return Constants.defaultBackgroundOpacity
            }
            let stored = defaults.double(forKey: Constants.UserDefaultsKey.backgroundOpacity)
            return min(max(stored, Constants.backgroundOpacityMin), Constants.backgroundOpacityMax)
        }
        set {
            defaults.set(min(max(newValue, Constants.backgroundOpacityMin), Constants.backgroundOpacityMax),
                         forKey: Constants.UserDefaultsKey.backgroundOpacity)
        }
    }

    // MARK: - 启动引导

    var hasPromptedForStartup: Bool {
        get {
            defaults.bool(forKey: Constants.UserDefaultsKey.hasPromptedForStartup)
        }
        set {
            defaults.set(newValue, forKey: Constants.UserDefaultsKey.hasPromptedForStartup)
        }
    }

    // MARK: - 数据结构版本

    // 初始化或升级偏好结构版本，为后续迁移保留入口。
    private func ensureSchemaVersion() {
        if defaults.integer(forKey: Constants.UserDefaultsKey.schemaVersion) < 1 {
            defaults.set(1, forKey: Constants.UserDefaultsKey.schemaVersion)
        }
    }

    // MARK: - 辅助方法

    // 将整数偏好限制在产品支持范围内，非法或缺失值回退到默认值。
    private static func clamp(_ value: Int, min: Int, max: Int, fallback: Int) -> Int {
        guard value >= min else { return fallback }
        return Swift.min(Swift.max(value, min), max)
    }

    // 读取位置偏好时兼容当前枚举和旧版本 raw value。
    private static func normalizedPosition(from raw: String?) -> Constants.OverlayPosition {
        guard let raw else { return .center }

        if let position = Constants.OverlayPosition(rawValue: raw) {
            return position
        }

        // [EN] Migration bridge for any older/hand-written values.
        // [CN] 迁移桥接：兼容旧版本或手写的历史值。
        // [JP] 旧版または手入力の値を移行するためのブリッジ。
        switch raw {
        case Constants.LegacyPosition.topLeft.rawValue:
            return .topLeft
        case Constants.LegacyPosition.top.rawValue:
            return .topCenter
        case Constants.LegacyPosition.topRight.rawValue:
            return .topRight
        case Constants.LegacyPosition.bottomLeft.rawValue:
            return .bottomLeft
        case Constants.LegacyPosition.bottomRight.rawValue:
            return .bottomRight
        default:
            return .center
        }
    }
}
