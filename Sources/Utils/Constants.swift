import Foundation
import CoreGraphics

/// Centralised constants — single source of truth for tuning.
enum Constants {

    // ── Timer ──────────────────────────────────────────────────
    /// Default interval between time flashes (seconds).
    static let defaultFlashInterval: TimeInterval = 300  // 5 min

    // ── Overlay display ────────────────────────────────────────
    /// How long the time is visible before fade-out begins.
    static let flashDuration: TimeInterval = 2.0

    /// Duration of the fade-out animation.
    static let fadeOutDuration: TimeInterval = 0.5

    /// Font size of the time digits.
    static let timeFontSize: CGFloat = 130

    // ── Window geometry ────────────────────────────────────────
    static let overlayWidth: CGFloat  = 520
    static let overlayHeight: CGFloat = 260

    // ── Bundle ─────────────────────────────────────────────────
    static let bundleIdentifier = "com.distracted.app"
}
