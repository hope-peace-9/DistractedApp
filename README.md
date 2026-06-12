# DistractedApp

Regain your sense of time at a glance.

![macOS 13.0+](https://img.shields.io/badge/macOS-13.0%2B-lightgrey?style=flat-square)
![Swift](https://img.shields.io/badge/Swift-5.0-orange?style=flat-square)
![License](https://img.shields.io/badge/License-MIT-blue?style=flat-square)

[简体中文](./README.zh-Hans.md) · [繁體中文](./README.zh-Hant.md) · [日本語](./README.ja.md)

## Overview

DistractedApp is a small macOS menu bar app for time awareness. Set an interval, and when the countdown ends, the current time appears in large type on screen, stays briefly, and then disappears automatically.

It does not take over your workflow. It simply reminds you to notice the time.

## Features

- Minimal: a pure digital clock that stays out of your workflow
- Lightweight: native Swift + AppKit build with very low memory usage
- Multilingual: 简体中文、繁體中文、English、日本語, following the system language automatically
- Launch at login: start with macOS without opening it manually
- Multi-display support: the floating window appears on the screen where the mouse is

## Download

Download the latest version from [GitHub Releases](https://github.com/hope-peace-9/DistractedApp/releases).

1. Download the latest `.dmg` file
2. Open the `.dmg` and drag the app into the Applications folder

This independently distributed app is not notarized by Apple, so macOS may show a Gatekeeper warning on first launch.

Method 1: Control-click the app icon, choose "Open", then click "Open" again in the confirmation dialog.

Method 2: run this command in Terminal:

```bash
xattr -dr com.apple.quarantine /Applications/Distracted.app
```

## Requirements

macOS 13.0 Ventura or later

## Feedback

- The "Bug Report" button in the app under Settings → About
- [GitHub Issues](https://github.com/hope-peace-9/DistractedApp/issues)

## Support

If this app is useful to you, you can support its maintenance through Buy Me a Coffee.

[Buy Me a Coffee](https://buymeacoffee.com/hope.peace)

## License

[MIT License](./LICENSE) · © 2026 hope-peace-9
