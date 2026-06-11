import Foundation

// ═══════════════════════════════════════════════════════════════
//  L10n — tiny NSLocalizedString wrapper
// ═══════════════════════════════════════════════════════════════
//
//  [EN] Keeps AppKit UI code concise while still using native
//       Localizable.strings lookup selected at app launch.
//
//  [CN] 让 AppKit UI 调用保持简洁，同时继续使用系统原生
//       Localizable.strings 机制；语言在 App 启动时由系统决定。
//
//  [JP] AppKit UI から簡潔に呼び出せるようにしつつ、
//       起動時にシステムが選択する Localizable.strings を使う。
// ═══════════════════════════════════════════════════════════════

enum L10n {

    // MARK: - Core Lookup

    /// [EN] Localize a key with optional printf-style arguments.
    /// [CN] 按 key 获取本地化字符串，并支持 printf 风格参数。
    /// [JP] key からローカライズ文字列を取得し、printf 形式の引数に対応。
    static func tr(_ key: String, _ arguments: CVarArg...) -> String {
        let format = NSLocalizedString(key, comment: "")
        guard !arguments.isEmpty else { return format }
        return String(format: format, locale: Locale.current, arguments: arguments)
    }

    // MARK: - App

    static var appName: String { tr("app.name") }
    static var appDisplayName: String { tr("app.displayName") }

    // MARK: - Menu

    static var menuToggle: String { tr("menu.toggle") }
    static var menuSettings: String { tr("menu.settings") }
    static var menuQuit: String { tr("menu.quit") }

    // MARK: - About

    static var aboutTitle: String { tr("about.title") }
    static var aboutMessage: String { tr("about.message") }
    static func aboutVersion(_ version: String) -> String { tr("about.version", version) }
    static func aboutSummary(intervalMinutes: Int, durationSeconds: Int, position: String) -> String {
        tr("about.summary", intervalMinutes, durationSeconds, position)
    }

    // MARK: - Settings

    static var settingsWindowTitle: String { tr("settings.window.title") }
    static var settingsSidebarSettings: String { tr("settings.sidebar.settings") }
    static var settingsSidebarAbout: String { tr("settings.sidebar.about") }
    static var settingsSectionReminder: String { tr("settings.section.reminder") }
    static var settingsSectionAppearance: String { tr("settings.section.appearance") }
    static var settingsIntervalLabel: String { tr("settings.interval.label") }
    static var settingsIntervalUnit: String { tr("settings.interval.unit") }
    static var settingsIntervalPlaceholder: String { tr("settings.interval.placeholder") }
    static var settingsIntervalError: String { tr("settings.interval.error") }
    static var settingsDurationLabel: String { tr("settings.duration.label") }
    static var settingsDurationUnit: String { tr("settings.duration.unit") }
    static var settingsDurationPlaceholder: String { tr("settings.duration.placeholder") }
    static var settingsDurationError: String { tr("settings.duration.error") }
    static var settingsPositionLabel: String { tr("settings.position.label") }
    static var settingsPositionHelp: String { tr("settings.position.help") }
    static var settingsFontSizeLabel: String { tr("settings.fontSize.label") }
    static var settingsFontSizeSmall: String { tr("settings.fontSize.small") }
    static var settingsFontSizeMedium: String { tr("settings.fontSize.medium") }
    static var settingsFontSizeLarge: String { tr("settings.fontSize.large") }
    static var settingsOpacityLabel: String { tr("settings.opacity.label") }
    static func settingsOpacityValue(_ value: Int) -> String { tr("settings.opacity.value", value) }
    static var settingsPreviewLabel: String { tr("settings.preview.label") }
    static var settingsConfirm: String { tr("settings.confirm") }

    // MARK: - Positions

    static func positionName(for position: Constants.OverlayPosition) -> String {
        switch position {
        case .topLeft:
            return tr("position.topLeft")
        case .topCenter:
            return tr("position.topCenter")
        case .topRight:
            return tr("position.topRight")
        case .middleLeft:
            return tr("position.middleLeft")
        case .center:
            return tr("position.center")
        case .middleRight:
            return tr("position.middleRight")
        case .bottomLeft:
            return tr("position.bottomLeft")
        case .bottomCenter:
            return tr("position.bottomCenter")
        case .bottomRight:
            return tr("position.bottomRight")
        }
    }

    // MARK: - Alerts

    static var alertCancel: String { tr("alert.cancel") }
    static var alertStartupTitle: String { tr("alert.startup.title") }
    static var alertStartupMessage: String { tr("alert.startup.message") }
    static var alertStartupYes: String { tr("alert.startup.yes") }
    static var alertStartupDontAskAgain: String { tr("alert.startup.dontAskAgain") }
}

extension String {

    /// [EN] Convenience bridge for one-off keys.
    /// [CN] 单次 key 调用的便利桥接。
    /// [JP] 単発の key 呼び出し用の便利ブリッジ。
    var localized: String {
        L10n.tr(self)
    }
}
