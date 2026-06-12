import Foundation

// ═══════════════════════════════════════════════════════════════
//  SettingsDraft — in-memory Settings window editing state
// ═══════════════════════════════════════════════════════════════
//
//  [EN] Keeps live preview responsive without writing UserDefaults
//       until the user confirms.
//
//  [CN] 保存设置窗口中的内存草稿，使实时预览立即响应，但在用户确认前
//       不写入 UserDefaults。
//
//  [JP] 設定ウィンドウ内の一時状態。ライブプレビューは即時反映し、
//       確認するまで UserDefaults には保存しない。
// ═══════════════════════════════════════════════════════════════

struct SettingsDraft {
    var intervalMinutes: Int
    var durationSeconds: Int
    var overlayPosition: Constants.OverlayPosition
    var fontScale: Constants.FontScale
    var backgroundOpacity: Double

    // 从当前持久化偏好生成一份可预览、可取消的内存草稿。
    init(preferences: PreferencesStore) {
        intervalMinutes = preferences.intervalMinutes
        durationSeconds = preferences.durationSeconds
        overlayPosition = preferences.overlayPosition
        fontScale = preferences.fontScale
        backgroundOpacity = preferences.backgroundOpacity
    }

    // 用户确认后才把草稿写回偏好存储。
    func apply(to preferences: PreferencesStore) {
        preferences.intervalMinutes = intervalMinutes
        preferences.durationSeconds = durationSeconds
        preferences.overlayPosition = overlayPosition
        preferences.fontScale = fontScale
        preferences.backgroundOpacity = backgroundOpacity
    }
}

struct OverlayConfiguration {
    var position: Constants.OverlayPosition
    var fontScale: Constants.FontScale
    var backgroundOpacity: Double

    // 从持久化偏好生成悬浮窗配置，供正式提醒使用。
    init(preferences: PreferencesStore) {
        position = preferences.overlayPosition
        fontScale = preferences.fontScale
        backgroundOpacity = preferences.backgroundOpacity
    }

    // 从设置草稿生成悬浮窗配置，供实时预览使用。
    init(draft: SettingsDraft) {
        position = draft.overlayPosition
        fontScale = draft.fontScale
        backgroundOpacity = draft.backgroundOpacity
    }
}
