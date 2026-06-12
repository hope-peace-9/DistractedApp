import Cocoa

// ═══════════════════════════════════════════════════════════════
//  main — application entry point
// ═══════════════════════════════════════════════════════════════
//
//  [EN] Starts the AppKit application and attaches AppDelegate for lifecycle wiring.
//  [CN] 启动 AppKit 应用，并挂载 AppDelegate 负责生命周期编排。
//  [JP] AppKit アプリを起動し、ライフサイクル管理用の AppDelegate を接続する。
// ═══════════════════════════════════════════════════════════════

// 显式保留 main.swift，确保脱离 Xcode 后的命令行编译入口稳定。
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
