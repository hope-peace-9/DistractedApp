# 分心了么

一眼找回时间感。

![macOS 13.0+](https://img.shields.io/badge/macOS-13.0%2B-lightgrey?style=flat-square)
![Swift](https://img.shields.io/badge/Swift-5.0-orange?style=flat-square)
![License](https://img.shields.io/badge/License-MIT-blue?style=flat-square)

[繁體中文](./README.zh-Hant.md) · [日本語](./README.ja.md) · [English](./README.md)

## 功能介绍

分心了么是一款 macOS 菜单栏时间提醒工具。设定一个时间间隔后，倒计时结束时，当前时间会以大字悬浮显示在屏幕上，短暂停留后自动消失。

它不接管你的工作流，只在需要时提醒你看一眼时间。

## 特性

- 极简：纯数字时钟，不干扰工作流
- 轻量：纯 Swift + AppKit 原生构建，内存占用极低
- 多语言：简体中文、繁體中文、English、日本語，跟随系统自动切换
- 开机自启：可随系统启动，无需手动打开
- 多显示器支持：悬浮窗始终出现在鼠标所在的屏幕

## 下载安装

前往 [GitHub Releases](https://github.com/hope-peace-9/DistractedApp/releases) 下载最新版本。

1. 下载最新版本 `.dmg` 文件
2. 打开 `.dmg`，将 app 拖入应用程序文件夹

独立 app 未经 Apple 公证，首次打开时 macOS 可能会显示 Gatekeeper 提示。

方法一：按住 Control 键点击 app 图标，选择「打开」，在弹出窗口中再次点击「打开」。

方法二：在终端中执行：

```bash
xattr -dr com.apple.quarantine /Applications/Distracted.app
```

## 系统要求

macOS 13.0 Ventura 或更高版本

## 问题反馈

- app 内「设置 → 关于」页面的「Bug 反馈」按钮
- [GitHub Issues](https://github.com/hope-peace-9/DistractedApp/issues)

## 赞助

如果这个 app 对你有帮助，可以通过微信或支付宝支持项目维护。

<p>
  <img src="Resources/QRcode/wechat_qr.png" alt="微信" width="160">
  <img src="Resources/QRcode/alipay_qr.png" alt="支付宝" width="160">
</p>

## 许可

[MIT License](./LICENSE) · © 2026 hope-peace-9
