import Cocoa

// ── Entry point ───────────────────────────────────────────────
// Explicit main.swift ensures CLI compilation works reliably.
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
