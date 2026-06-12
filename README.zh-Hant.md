# 分心了麼

一眼找回時間感。

![macOS 13.0+](https://img.shields.io/badge/macOS-13.0%2B-lightgrey?style=flat-square)
![Swift](https://img.shields.io/badge/Swift-5.0-orange?style=flat-square)
![License](https://img.shields.io/badge/License-MIT-blue?style=flat-square)

[简体中文](./README.zh-Hans.md) · [日本語](./README.ja.md) · [English](./README.md)

## 功能介紹

分心了麼是一款 macOS 選單列時間提醒工具。設定時間間隔後，倒數結束時，當前時間會以大字懸浮顯示在螢幕上，短暫停留後自動消失。

它不接管你的工作流程，只在需要時提醒你看一眼時間。

## 特性

- 極簡：純數字時鐘，不干擾工作流程
- 輕量：純 Swift + AppKit 原生建置，記憶體占用極低
- 多語言：简体中文、繁體中文、English、日本語，跟隨系統自動切換
- 開機自啟：可隨系統啟動，無需手動開啟
- 多顯示器支援：懸浮窗始終出現在滑鼠所在的螢幕

## 下載安裝

前往 [GitHub Releases](https://github.com/hope-peace-9/DistractedApp/releases) 下載最新版本。

1. 下載最新版本 `.dmg` 檔案
2. 打開 `.dmg`，將 app 拖入「應用程式」資料夾

獨立 app 未經 Apple 公證，首次開啟時 macOS 可能會顯示 Gatekeeper 提示。

方法一：按住 Control 鍵點擊 app 圖示，選擇「打開」，在彈出視窗中再次點擊「打開」。

方法二：在終端機中執行：

```bash
xattr -dr com.apple.quarantine /Applications/Distracted.app
```

## 系統需求

macOS 13.0 Ventura 或更新版本

## 問題回報

- app 內「設定 → 關於」頁面的「Bug 回饋」按鈕
- [GitHub Issues](https://github.com/hope-peace-9/DistractedApp/issues)

## 贊助

如果這個 app 對你有幫助，可以透過 Buy Me a Coffee 支援專案維護。

[Buy Me a Coffee](https://buymeacoffee.com/hope.peace)

## 授權

[MIT License](./LICENSE) · © 2026 hope-peace-9
