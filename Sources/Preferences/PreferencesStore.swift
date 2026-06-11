import Foundation

// ═══════════════════════════════════════════════════════════════
//  PreferencesStore — typed UserDefaults gateway
// ═══════════════════════════════════════════════════════════════
//
//  [EN] Responsibilities:
//       1. Centralise all UserDefaults keys and fallback values.
//       2. Clamp persisted values into valid Phase 3 ranges.
//       3. Keep legacy raw values readable while new UI is introduced.
//
//  [CN] 职责：
//       1. 集中管理全部 UserDefaults 键与默认值。
//       2. 将持久化数据限制在 Phase 3 的合法范围内。
//       3. 在新 UI 逐步接入期间兼容旧 raw value。
//
//  [JP] 責務：
//       1. UserDefaults のキーと既定値を一元管理。
//       2. 保存値を Phase 3 の有効範囲に丸める。
//       3. 新 UI 導入中も旧 raw value を読み取れるようにする。
// ═══════════════════════════════════════════════════════════════

final class PreferencesStore {

    // MARK: - Shared

    static let shared = PreferencesStore()

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        ensureSchemaVersion()
    }

    // MARK: - Reminder Enabled

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

    // MARK: - Interval

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

    // MARK: - Duration

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

    // MARK: - Position

    var overlayPosition: Constants.OverlayPosition {
        get {
            let raw = defaults.string(forKey: Constants.UserDefaultsKey.position)
            return Self.normalizedPosition(from: raw)
        }
        set {
            defaults.set(newValue.rawValue, forKey: Constants.UserDefaultsKey.position)
        }
    }

    /// [EN] Legacy String bridge used by the current overlay/menu until Phase 3 UI lands.
    /// [CN] 旧 String 桥接：供当前弹窗/菜单继续使用，直到 Phase 3 UI 接入。
    /// [JP] 既存のオーバーレイ/メニュー向け String ブリッジ。
    var overlayPositionRawValue: String {
        overlayPosition.rawValue
    }

    // MARK: - Visuals

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

    // MARK: - Startup Onboarding

    var hasPromptedForStartup: Bool {
        get {
            defaults.bool(forKey: Constants.UserDefaultsKey.hasPromptedForStartup)
        }
        set {
            defaults.set(newValue, forKey: Constants.UserDefaultsKey.hasPromptedForStartup)
        }
    }

    // MARK: - Schema

    private func ensureSchemaVersion() {
        if defaults.integer(forKey: Constants.UserDefaultsKey.schemaVersion) < 1 {
            defaults.set(1, forKey: Constants.UserDefaultsKey.schemaVersion)
        }
    }

    // MARK: - Helpers

    private static func clamp(_ value: Int, min: Int, max: Int, fallback: Int) -> Int {
        guard value >= min else { return fallback }
        return Swift.min(Swift.max(value, min), max)
    }

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
