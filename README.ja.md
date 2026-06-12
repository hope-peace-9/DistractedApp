# DistractedApp

今、何時か。一目でわかる。

![macOS 13.0+](https://img.shields.io/badge/macOS-13.0%2B-lightgrey?style=flat-square)
![Swift](https://img.shields.io/badge/Swift-5.0-orange?style=flat-square)
![License](https://img.shields.io/badge/License-MIT-blue?style=flat-square)

[简体中文](./README.zh-Hans.md) · [繁體中文](./README.zh-Hant.md) · [English](./README.md)

## 概要

DistractedApp は、macOS のメニューバーに常駐する時間リマインダーです。時間間隔を設定すると、カウントダウン終了時に現在時刻が大きく画面に表示され、短く表示されたあと自動で消えます。

作業の流れを止めず、必要なときだけ時間を知らせます。

## 特長

- ミニマル：数字だけの時計で、作業を妨げない
- 軽量：純 Swift + AppKit のネイティブ構成で、メモリ使用量を抑制
- 多言語：简体中文、繁體中文、English、日本語に対応し、システム言語に合わせて自動切替
- ログイン時に起動：システム起動時に自動で起動可能
- マルチディスプレイ対応：フローティングウィンドウは常にマウスがある画面に表示

## ダウンロードとインストール

[GitHub Releases](https://github.com/hope-peace-9/DistractedApp/releases) から最新版をダウンロードしてください。

1. 最新版の `.dmg` ファイルをダウンロード
2. `.dmg` を開き、app を「アプリケーション」フォルダへドラッグ

この独立配布版 app は Apple の公証を受けていないため、初回起動時に macOS の Gatekeeper 警告が表示される場合があります。

方法 1：Control キーを押しながら app アイコンをクリックし、「開く」を選択します。表示された確認画面でもう一度「開く」をクリックします。

方法 2：ターミナルで次のコマンドを実行します。

```bash
xattr -dr com.apple.quarantine /Applications/Distracted.app
```

## 動作環境

macOS 13.0 Ventura 以降

## フィードバック

- app 内の「設定 → このアプリについて」画面にある「Bug 反馈」ボタン
- [GitHub Issues](https://github.com/hope-peace-9/DistractedApp/issues)

## サポート

この app が役に立った場合は、Buy Me a Coffee から開発を支援できます。

[Buy Me a Coffee](https://buymeacoffee.com/hope.peace)

## ライセンス

[MIT License](./LICENSE) · © 2026 hope-peace-9
