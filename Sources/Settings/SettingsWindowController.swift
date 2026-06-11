import Cocoa

// ═══════════════════════════════════════════════════════════════
//  SettingsWindowController — HIG-polished Settings UI
// ═══════════════════════════════════════════════════════════════
//
//  [EN] Pure AppKit settings window. Edits stay in an in-memory
//       draft for live preview and are persisted only on Confirm.
//
//  [CN] 纯 AppKit 设置窗口。编辑内容先保存在内存草稿中用于实时预览，
//       只有点击“确认”后才写入 UserDefaults。
//
//  [JP] 純 AppKit の設定ウィンドウ。編集内容はライブプレビュー用の
//       一時状態に保持し、確認後のみ UserDefaults に保存する。
// ═══════════════════════════════════════════════════════════════

final class SettingsWindowController: NSWindowController, NSWindowDelegate {

    var onDraftChanged: ((SettingsDraft) -> Void)?
    var onConfirm: ((SettingsDraft) -> Void)?
    var onWindowWillClose: (() -> Void)?

    private let rootView: SettingsRootView

    init(preferences: PreferencesStore) {
        rootView = SettingsRootView(preferences: preferences)

        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 720, height: 540),
                              styleMask: [.titled, .closable, .miniaturizable],
                              backing: .buffered,
                              defer: false)
        window.title = L10n.settingsWindowTitle
        window.isReleasedWhenClosed = false
        window.center()
        window.contentView = rootView

        super.init(window: window)
        window.delegate = self

        rootView.onDraftChanged = { [weak self] draft in
            self?.onDraftChanged?(draft)
        }
        rootView.onConfirm = { [weak self] draft in
            self?.onConfirm?(draft)
            self?.close()
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func showAndFocus() {
        rootView.refreshFromPreferences()
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func windowWillClose(_ notification: Notification) {
        onWindowWillClose?()
    }
}

// MARK: - Root

private final class SettingsRootView: NSView {

    var onDraftChanged: ((SettingsDraft) -> Void)?
    var onConfirm: ((SettingsDraft) -> Void)?

    private let preferences: PreferencesStore
    private let detailContainer = NSView()
    private let settingsButton = NSButton(title: L10n.settingsSidebarSettings, target: nil, action: nil)
    private let aboutButton = NSButton(title: L10n.settingsSidebarAbout, target: nil, action: nil)
    private let settingsSelectionPill = SelectionPillView()
    private let aboutSelectionPill    = SelectionPillView()

    private lazy var settingsPane = SettingsPaneView(preferences: preferences)
    private lazy var aboutPane = AboutPaneView()

    init(preferences: PreferencesStore) {
        self.preferences = preferences
        super.init(frame: .zero)
        buildUI()
        showSettings()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func refreshFromPreferences() {
        settingsPane.resetDraftFromPreferences()
        showSettings()
    }

    private func buildUI() {
        let sidebar = NSVisualEffectView()
        sidebar.material = .sidebar
        sidebar.blendingMode = .behindWindow
        sidebar.state = .active
        sidebar.translatesAutoresizingMaskIntoConstraints = false

        configureSidebarButton(settingsButton, action: #selector(showSettings))
        configureSidebarButton(aboutButton, action: #selector(showAbout))

        settingsSelectionPill.translatesAutoresizingMaskIntoConstraints = false
        aboutSelectionPill.translatesAutoresizingMaskIntoConstraints    = false
        // [EN] Buttons first, pills last — pills sit on top in Z-order.
        //      ignoresMouseEvents = true on each pill lets clicks fall through
        //      to the button underneath, so interaction is unaffected.
        // [CN] 先加按钮，后加药丸 — 药丸在 Z 轴上位于最顶层。
        //      药丸的 ignoresMouseEvents = true 让点击穿透到下方按钮，交互不受影响。
        // [JP] ボタンを先に追加し、ピルを後に — ピルが Z 順で最前面になる。
        //      ピルに ignoresMouseEvents = true を設定してクリックを下のボタンに通過させる。
        sidebar.addSubview(settingsButton)
        sidebar.addSubview(aboutButton)
        sidebar.addSubview(settingsSelectionPill)
        sidebar.addSubview(aboutSelectionPill)

        // [EN] Do NOT set wantsLayer/backgroundColor here.
        //      CALayer.backgroundColor stores a CGColor snapshot taken at init time and
        //      never updates when the system appearance changes — producing a frozen
        //      dark background in light mode. A plain NSView draws nothing itself;
        //      the window's own backgroundColor (NSColor.windowBackgroundColor, which
        //      IS dynamic) shows through and follows appearance changes in real time.
        // [CN] 不在这里设置 wantsLayer / backgroundColor。
        //      CALayer.backgroundColor 保存的是初始化时拍下的 CGColor 快照，不会随
        //      系统 appearance 变化 —— 导致明亮模式下背景冻结为深色。纯 NSView 本身
        //      不绘制背景，窗口的 backgroundColor (NSColor.windowBackgroundColor，
        //      本身是动态语义色) 会透过来，实时跟随系统明暗切换。
        // [JP] ここで wantsLayer / backgroundColor を設定しない。
        //      CALayer.backgroundColor は初期化時に取得した CGColor のスナップショットを
        //      保持し、システムの appearance 変化で更新されない —— ライトモードで
        //      暗い背景が固まる原因になる。素の NSView は自身では何も描画しないため、
        //      ウィンドウの backgroundColor (NSColor.windowBackgroundColor、これは
        //      動的なセマンティックカラー) が透けて見え、明暗切替をリアルタイムで追従する。
        detailContainer.translatesAutoresizingMaskIntoConstraints = false

        addSubview(sidebar)
        addSubview(detailContainer)

        // [EN] Sidebar top margin that is mirrored at the bottom for symmetric spacing.
        // [CN] 侧边栏顶部间距，底部保持相同值以形成视觉对称。
        // [JP] 上下対称になるようにサイドバーの上下マージンを同値にする。
        let sidebarEdge: CGFloat = 18

        NSLayoutConstraint.activate([
            sidebar.leadingAnchor.constraint(equalTo: leadingAnchor),
            sidebar.topAnchor.constraint(equalTo: topAnchor),
            sidebar.bottomAnchor.constraint(equalTo: bottomAnchor),
            sidebar.widthAnchor.constraint(equalToConstant: 172),

            settingsButton.topAnchor.constraint(equalTo: sidebar.topAnchor, constant: sidebarEdge),
            settingsButton.centerXAnchor.constraint(equalTo: sidebar.centerXAnchor),

            aboutButton.bottomAnchor.constraint(equalTo: sidebar.bottomAnchor, constant: -sidebarEdge),
            aboutButton.centerXAnchor.constraint(equalTo: sidebar.centerXAnchor),

            settingsSelectionPill.topAnchor.constraint(equalTo: settingsButton.topAnchor),
            settingsSelectionPill.bottomAnchor.constraint(equalTo: settingsButton.bottomAnchor),
            settingsSelectionPill.leadingAnchor.constraint(equalTo: settingsButton.leadingAnchor),
            settingsSelectionPill.trailingAnchor.constraint(equalTo: settingsButton.trailingAnchor),

            aboutSelectionPill.topAnchor.constraint(equalTo: aboutButton.topAnchor),
            aboutSelectionPill.bottomAnchor.constraint(equalTo: aboutButton.bottomAnchor),
            aboutSelectionPill.leadingAnchor.constraint(equalTo: aboutButton.leadingAnchor),
            aboutSelectionPill.trailingAnchor.constraint(equalTo: aboutButton.trailingAnchor),

            detailContainer.leadingAnchor.constraint(equalTo: sidebar.trailingAnchor),
            detailContainer.trailingAnchor.constraint(equalTo: trailingAnchor),
            detailContainer.topAnchor.constraint(equalTo: topAnchor),
            detailContainer.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        settingsPane.onDraftChanged = { [weak self] draft in
            self?.onDraftChanged?(draft)
        }
        settingsPane.onConfirm = { [weak self] draft in
            self?.onConfirm?(draft)
        }
    }

    private func configureSidebarButton(_ button: NSButton, action: Selector) {
        button.target = self
        button.action = action
        button.bezelStyle = .recessed
        button.setButtonType(.toggle)
        button.alignment = .center
        button.translatesAutoresizingMaskIntoConstraints = false
        button.widthAnchor.constraint(equalToConstant: 144).isActive = true
        button.wantsLayer = true
        applyButtonShadow(button)
    }

    private func applyButtonShadow(_ button: NSButton) {
        let isDark = button.effectiveAppearance
            .bestMatch(from: [.darkAqua, .aqua]) == .darkAqua

        if isDark {
            // [EN] In dark mode a black shadow vanishes against the dark sidebar.
            //      Use a faint white ambient glow (radius 3, no offset) to suggest
            //      elevation through brightness contrast instead of darkness.
            // [CN] 暗黑模式下黑色阴影会和深色侧边栏融为一体。
            //      改用极淡的白色环境光晕（radius 3，无偏移），以亮度差代替深度差来体现浮起感。
            // [JP] ダークモードでは黒いシャドウが暗いサイドバーに溶け込む。
            //      代わりに非常に薄い白のアンビエントグロー（radius 3・オフセットなし）で
            //      輝度差による浮き上がり感を表現する。
            button.layer?.shadowColor   = NSColor(white: 1.0, alpha: 0.10).cgColor
            button.layer?.shadowOpacity = 1
            button.layer?.shadowRadius  = 3
            button.layer?.shadowOffset  = NSSize(width: 0, height: 0)
        } else {
            // [EN] In light mode a standard downward dark drop shadow gives depth.
            // [CN] 明亮模式下使用标准向下的深色投影来表现深度。
            // [JP] ライトモードでは標準の下向き暗いドロップシャドウで奥行きを出す。
            button.layer?.shadowColor   = NSColor(white: 0.0, alpha: 0.14).cgColor
            button.layer?.shadowOpacity = 1
            button.layer?.shadowRadius  = 3
            button.layer?.shadowOffset  = NSSize(width: 0, height: -1)
        }
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        applyButtonShadow(settingsButton)
        applyButtonShadow(aboutButton)
    }

    @objc
    private func showSettings() {
        settingsButton.state = .on
        aboutButton.state    = .off
        settingsSelectionPill.isHidden = false
        aboutSelectionPill.isHidden    = true
        setDetailView(settingsPane)
    }

    @objc
    private func showAbout() {
        settingsButton.state = .off
        aboutButton.state    = .on
        settingsSelectionPill.isHidden = true
        aboutSelectionPill.isHidden    = false
        setDetailView(aboutPane)
    }

    private func setDetailView(_ view: NSView) {
        detailContainer.subviews.forEach { $0.removeFromSuperview() }
        view.translatesAutoresizingMaskIntoConstraints = false
        detailContainer.addSubview(view)
        NSLayoutConstraint.activate([
            view.leadingAnchor.constraint(equalTo: detailContainer.leadingAnchor),
            view.trailingAnchor.constraint(equalTo: detailContainer.trailingAnchor),
            view.topAnchor.constraint(equalTo: detailContainer.topAnchor),
            view.bottomAnchor.constraint(equalTo: detailContainer.bottomAnchor)
        ])
    }
}

// MARK: - Settings Pane

private final class SettingsPaneView: NSView, NSTextFieldDelegate {

    var onDraftChanged: ((SettingsDraft) -> Void)?
    var onConfirm: ((SettingsDraft) -> Void)?

    private let preferences: PreferencesStore
    private var draft: SettingsDraft

    private let intervalField = NSTextField()
    private let durationField = NSTextField()
    private let positionControl = PositionMatrixControl()
    private let validationPopover = ValidationPopover()
    private let fontPopup = NSPopUpButton()
    private let opacitySlider = NSSlider(value: Constants.defaultBackgroundOpacity,
                                         minValue: Constants.backgroundOpacityMin,
                                         maxValue: Constants.backgroundOpacityMax,
                                         target: nil,
                                         action: nil)
    private let opacityValueLabel = NSTextField(labelWithString: "")
    private let confirmButton = NSButton(title: L10n.settingsConfirm, target: nil, action: nil)

    private var lastValidInterval: Int
    private var lastValidDuration: Int

    init(preferences: PreferencesStore) {
        self.preferences = preferences
        draft = SettingsDraft(preferences: preferences)
        lastValidInterval = draft.intervalMinutes
        lastValidDuration = draft.durationSeconds
        super.init(frame: .zero)
        buildUI()
        refreshFieldsFromDraft()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func resetDraftFromPreferences() {
        draft = SettingsDraft(preferences: preferences)
        lastValidInterval = draft.intervalMinutes
        lastValidDuration = draft.durationSeconds
        refreshFieldsFromDraft()
        onDraftChanged?(draft)
    }

    private func buildUI() {
        let root = NSStackView()
        root.orientation = .vertical
        root.alignment = .leading
        root.spacing = 18
        root.edgeInsets = NSEdgeInsets(top: 32, left: 36, bottom: 24, right: 36)
        root.translatesAutoresizingMaskIntoConstraints = false
        addSubview(root)

        let title = NSTextField(labelWithString: L10n.settingsWindowTitle)
        title.font = .systemFont(ofSize: 28, weight: .semibold)
        title.textColor = .labelColor
        root.addArrangedSubview(title)

        root.addArrangedSubview(sectionTitle(L10n.settingsSectionReminder))
        configureField(intervalField, placeholder: L10n.settingsIntervalPlaceholder)
        configureField(durationField, placeholder: L10n.settingsDurationPlaceholder)
        root.addArrangedSubview(formRow(label: L10n.settingsIntervalLabel,
                                        control: intervalField,
                                        unit: L10n.settingsIntervalUnit))
        root.addArrangedSubview(formRow(label: L10n.settingsDurationLabel,
                                        control: durationField,
                                        unit: L10n.settingsDurationUnit))

        root.addArrangedSubview(divider())
        root.addArrangedSubview(sectionTitle(L10n.settingsPositionLabel))
        let help = NSTextField(labelWithString: L10n.settingsPositionHelp)
        help.textColor = .secondaryLabelColor
        help.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        root.addArrangedSubview(help)

        positionControl.target = self
        positionControl.action = #selector(positionChanged(_:))
        let positionContainer = NSView()
        positionContainer.translatesAutoresizingMaskIntoConstraints = false
        positionContainer.addSubview(positionControl)
        positionControl.translatesAutoresizingMaskIntoConstraints = false
        root.addArrangedSubview(positionContainer)

        root.addArrangedSubview(divider())
        root.addArrangedSubview(sectionTitle(L10n.settingsSectionAppearance))
        configureFontPopup()
        root.addArrangedSubview(formRow(label: L10n.settingsFontSizeLabel,
                                        control: fontPopup,
                                        unit: ""))
        configureOpacitySlider()
        root.addArrangedSubview(opacityRow())

        let spacer = NSView()
        spacer.translatesAutoresizingMaskIntoConstraints = false
        root.addArrangedSubview(spacer)

        configureConfirmButton()
        let buttonSpacer = NSView()
        buttonSpacer.translatesAutoresizingMaskIntoConstraints = false
        let buttonRow = NSStackView(views: [buttonSpacer, confirmButton])
        buttonRow.orientation = .horizontal
        buttonRow.alignment = .centerY
        buttonRow.distribution = .fill
        buttonRow.spacing = 0
        buttonRow.translatesAutoresizingMaskIntoConstraints = false
        root.addArrangedSubview(buttonRow)

        NSLayoutConstraint.activate([
            root.leadingAnchor.constraint(equalTo: leadingAnchor),
            root.trailingAnchor.constraint(equalTo: trailingAnchor),
            root.topAnchor.constraint(equalTo: topAnchor),
            root.bottomAnchor.constraint(equalTo: bottomAnchor),

            positionContainer.widthAnchor.constraint(equalTo: root.widthAnchor, constant: -72),
            positionContainer.heightAnchor.constraint(equalToConstant: 160),
            positionControl.centerXAnchor.constraint(equalTo: positionContainer.centerXAnchor),
            positionControl.centerYAnchor.constraint(equalTo: positionContainer.centerYAnchor),

            spacer.heightAnchor.constraint(greaterThanOrEqualToConstant: 1),
            buttonRow.widthAnchor.constraint(equalTo: root.widthAnchor, constant: -72)
        ])
    }

    private func sectionTitle(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = .systemFont(ofSize: 17, weight: .semibold)
        label.textColor = .labelColor
        return label
    }

    private func divider() -> NSBox {
        let box = NSBox()
        box.boxType = .separator
        box.translatesAutoresizingMaskIntoConstraints = false
        box.widthAnchor.constraint(equalToConstant: 456).isActive = true
        return box
    }

    private func configureField(_ field: NSTextField, placeholder: String) {
        field.placeholderString = placeholder
        field.delegate = self
        field.alignment = .right
        field.isBezeled = true
        field.drawsBackground = true
        field.backgroundColor = .controlBackgroundColor
        field.font = .monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        field.translatesAutoresizingMaskIntoConstraints = false
        field.widthAnchor.constraint(equalToConstant: 92).isActive = true
        field.wantsLayer = true
        field.layer?.shadowColor = NSColor.shadowColor.withAlphaComponent(0.18).cgColor
        field.layer?.shadowOpacity = 1
        field.layer?.shadowRadius = 2
        field.layer?.shadowOffset = NSSize(width: 0, height: -1)
    }

    private func formRow(label: String, control: NSView, unit: String) -> NSStackView {
        let name = NSTextField(labelWithString: label)
        name.alignment = .right
        name.textColor = .labelColor
        name.translatesAutoresizingMaskIntoConstraints = false
        name.widthAnchor.constraint(equalToConstant: 120).isActive = true

        let unitLabel = NSTextField(labelWithString: unit)
        unitLabel.textColor = .secondaryLabelColor
        unitLabel.translatesAutoresizingMaskIntoConstraints = false
        unitLabel.widthAnchor.constraint(equalToConstant: 58).isActive = true

        let row = NSStackView(views: [name, control, unitLabel])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 10
        return row
    }

    private func configureFontPopup() {
        fontPopup.addItem(withTitle: L10n.settingsFontSizeSmall)
        fontPopup.lastItem?.tag = tag(for: .small)
        fontPopup.addItem(withTitle: L10n.settingsFontSizeMedium)
        fontPopup.lastItem?.tag = tag(for: .medium)
        fontPopup.addItem(withTitle: L10n.settingsFontSizeLarge)
        fontPopup.lastItem?.tag = tag(for: .large)
        fontPopup.target = self
        fontPopup.action = #selector(fontScaleChanged(_:))
        fontPopup.translatesAutoresizingMaskIntoConstraints = false
        fontPopup.widthAnchor.constraint(equalToConstant: 144).isActive = true
    }

    private func configureOpacitySlider() {
        opacitySlider.target = self
        opacitySlider.action = #selector(opacityChanged(_:))
        opacitySlider.translatesAutoresizingMaskIntoConstraints = false
        opacitySlider.widthAnchor.constraint(equalToConstant: 190).isActive = true
    }

    private func opacityRow() -> NSStackView {
        let name = NSTextField(labelWithString: L10n.settingsOpacityLabel)
        name.alignment = .right
        name.textColor = .labelColor
        name.translatesAutoresizingMaskIntoConstraints = false
        name.widthAnchor.constraint(equalToConstant: 120).isActive = true

        opacityValueLabel.textColor = .secondaryLabelColor
        opacityValueLabel.translatesAutoresizingMaskIntoConstraints = false
        opacityValueLabel.widthAnchor.constraint(equalToConstant: 48).isActive = true

        let row = NSStackView(views: [name, opacitySlider, opacityValueLabel])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 10
        return row
    }

    private func configureConfirmButton() {
        confirmButton.target = self
        confirmButton.action = #selector(confirm)
        confirmButton.bezelStyle = .rounded
        confirmButton.keyEquivalent = "\r"
        confirmButton.contentTintColor = .controlAccentColor
        confirmButton.setContentHuggingPriority(.required, for: .horizontal)
        confirmButton.setContentCompressionResistancePriority(.required, for: .horizontal)
    }

    private func refreshFieldsFromDraft() {
        intervalField.stringValue = "\(draft.intervalMinutes)"
        durationField.stringValue = "\(draft.durationSeconds)"
        positionControl.selectedPosition = draft.overlayPosition
        fontPopup.selectItem(withTag: tag(for: draft.fontScale))
        opacitySlider.doubleValue = draft.backgroundOpacity
        opacityValueLabel.stringValue = L10n.settingsOpacityValue(Int(draft.backgroundOpacity * 100))
    }

    func controlTextDidChange(_ obj: Notification) {
        guard let field = obj.object as? NSTextField else { return }
        let digits = field.stringValue.filter(\.isNumber)
        if field.stringValue != String(digits) {
            field.stringValue = String(digits)
        }

        if field === intervalField {
            applyIntervalInput()
        } else if field === durationField {
            applyDurationInput()
        }
    }

    private func applyIntervalInput() {
        guard !intervalField.stringValue.isEmpty else { return }
        guard let value = Int(intervalField.stringValue),
              value >= Constants.intervalMinMinutes,
              value <= Constants.intervalMaxMinutes else {
            showError(intervalField, text: L10n.settingsIntervalError, edge: .minY)
            intervalField.stringValue = "\(lastValidInterval)"
            return
        }

        lastValidInterval = value
        draft.intervalMinutes = value
        onDraftChanged?(draft)
    }

    private func applyDurationInput() {
        guard !durationField.stringValue.isEmpty else { return }
        guard let value = Int(durationField.stringValue),
              value >= Constants.durationMin,
              value <= Constants.durationMax else {
            showError(durationField, text: L10n.settingsDurationError, edge: .maxY)
            durationField.stringValue = "\(lastValidDuration)"
            return
        }

        lastValidDuration = value
        draft.durationSeconds = value
        onDraftChanged?(draft)
    }

    private func showError(_ anchor: NSTextField, text: String, edge: NSRectEdge) {
        validationPopover.show(message: text, anchoredTo: anchor, preferredEdge: edge)
    }

    @objc
    private func positionChanged(_ sender: PositionMatrixControl) {
        draft.overlayPosition = sender.selectedPosition
        onDraftChanged?(draft)
    }

    @objc
    private func fontScaleChanged(_ sender: NSPopUpButton) {
        switch sender.selectedTag() {
        case tag(for: .small):
            draft.fontScale = .small
        case tag(for: .large):
            draft.fontScale = .large
        default:
            draft.fontScale = .medium
        }
        onDraftChanged?(draft)
    }

    @objc
    private func opacityChanged(_ sender: NSSlider) {
        draft.backgroundOpacity = sender.doubleValue
        opacityValueLabel.stringValue = L10n.settingsOpacityValue(Int(sender.doubleValue * 100))
        onDraftChanged?(draft)
    }

    @objc
    private func confirm() {
        onConfirm?(draft)
    }

    private func tag(for scale: Constants.FontScale) -> Int {
        switch scale {
        case .small:
            return 1
        case .medium:
            return 2
        case .large:
            return 3
        }
    }
}

// MARK: - About Pane

private final class AboutPaneView: NSView {

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        buildUI()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        buildUI()
    }

    private func buildUI() {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.edgeInsets = NSEdgeInsets(top: 40, left: 40, bottom: 40, right: 40)
        stack.translatesAutoresizingMaskIntoConstraints = false

        let title = NSTextField(labelWithString: L10n.aboutTitle)
        title.font = .systemFont(ofSize: 26, weight: .semibold)
        title.textColor = .labelColor

        let message = NSTextField(labelWithString: L10n.aboutMessage)
        message.font = .systemFont(ofSize: NSFont.systemFontSize)
        message.textColor = .labelColor

        let version = NSTextField(labelWithString: L10n.aboutVersion("1.0.0"))
        version.textColor = .secondaryLabelColor

        stack.addArrangedSubview(title)
        stack.addArrangedSubview(message)
        stack.addArrangedSubview(version)
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor),
            stack.topAnchor.constraint(equalTo: topAnchor)
        ])
    }
}

// MARK: - Selection Pill

// ═══════════════════════════════════════════════════════════════
//  SelectionPillView — sidebar active-tab highlight background
// ═══════════════════════════════════════════════════════════════
//
//  [EN] A rounded-rect layer-backed view rendered behind each sidebar
//       button. Visible only for the currently selected tab; hidden
//       for all others. Uses controlAccentColor at low opacity so
//       the tint follows the user's chosen accent color and works
//       in both light and dark mode.
//       CGColor (layer.backgroundColor) is a static snapshot, so
//       viewDidChangeEffectiveAppearance() re-snapshots it every time
//       the system appearance or accent color changes.
//
//  [CN] 一个圆角矩形的 layer 视图，渲染在每个侧边栏按钮的背后。
//       只对当前选中的 Tab 可见；其余隐藏。使用低透明度的
//       controlAccentColor，跟随用户的强调色，明暗模式均适用。
//       layer.backgroundColor 是 CGColor（静态快照），因此在
//       viewDidChangeEffectiveAppearance() 里每次重新快照。
//
//  [JP] 各サイドバーボタンの背面に描画される角丸レイヤービュー。
//       現在選択中のタブにのみ表示し、その他は非表示にする。
//       controlAccentColor を低い不透明度で使用するため、
//       ユーザーのアクセントカラーに追従し明暗両モードで機能する。
//       layer.backgroundColor は CGColor（静的スナップショット）の
//       ため、viewDidChangeEffectiveAppearance() で毎回再取得する。
// ═══════════════════════════════════════════════════════════════

private final class SelectionPillView: NSView {

    override init(frame: NSRect) {
        super.init(frame: frame)
        isHidden = true
        wantsLayer = true
        layer?.cornerRadius = 6
        refreshLayerColor()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
        layer?.cornerRadius = 6
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        refreshLayerColor()
    }

    // [EN] Return nil so all mouse events fall through to the button underneath.
    //      NSView.hitTest returning nil = "this view is invisible to the mouse".
    // [CN] 返回 nil 让所有鼠标事件穿透到下方的按钮。
    //      NSView.hitTest 返回 nil 表示该视图对鼠标不可见。
    // [JP] nil を返してすべてのマウスイベントを下のボタンに通過させる。
    //      NSView.hitTest が nil を返す = マウスに対して不可視。
    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    private func refreshLayerColor() {
        let isDark = effectiveAppearance
            .bestMatch(from: [.darkAqua, .aqua]) == .darkAqua

        if isDark {
            // [EN] Dark mode: overlay a translucent white to make the selected button
            //      lighter/brighter than the unselected siblings.
            // [CN] 暗黑模式：叠加半透明白色，使选中按钮比未选中的更亮/更浅。
            // [JP] ダークモード：半透明の白を重ね、選択中ボタンを未選択より明るく見せる。
            layer?.backgroundColor = NSColor(white: 1.0, alpha: 0.11).cgColor
        } else {
            // [EN] Light mode: overlay a translucent black to make the selected button
            //      darker/deeper than the unselected siblings.
            // [CN] 明亮模式：叠加半透明黑色，使选中按钮比未选中的更深/更暗。
            // [JP] ライトモード：半透明の黒を重ね、選択中ボタンを未選択より暗く見せる。
            layer?.backgroundColor = NSColor(white: 0.0, alpha: 0.09).cgColor
        }
    }
}

// MARK: - Validation Popover

// ═══════════════════════════════════════════════════════════════
//  ValidationPopover — floating error bubble anchored to a field
// ═══════════════════════════════════════════════════════════════
//
//  [EN] Uses NSPopover so the error message is completely detached
//       from the host layout. The popover's native arrow, rounded
//       corners, material background, and shadow are all provided
//       by AppKit at no extra cost. The bubble auto-dismisses after
//       `autoDismissAfter` seconds or when the user clicks outside.
//
//  [CN] 用 NSPopover 实现错误提示，使其完全脱离宿主布局。箭头、圆角、
//       材质背景和阴影全部由 AppKit 免费提供。气泡会在 `autoDismissAfter`
//       秒后自动消失，或在用户点击其他地方时立即消失。
//
//  [JP] NSPopover を使ってエラーメッセージをホストレイアウトから完全に
//       切り離す。矢印・角丸・マテリアル背景・影はすべて AppKit が
//       無償で提供する。`autoDismissAfter` 秒後、またはユーザーが他を
//       クリックした時点で自動的に閉じる。
// ═══════════════════════════════════════════════════════════════

private final class ValidationPopover: NSObject {

    private let popover = NSPopover()
    private let label   = NSTextField(labelWithString: "")
    private var dismissItem: DispatchWorkItem?

    private static let hPad: CGFloat     = 12
    private static let vPad: CGFloat     = 9
    private static let maxWidth: CGFloat = 256

    override init() {
        super.init()

        label.font                 = .systemFont(ofSize: NSFont.smallSystemFontSize, weight: .medium)
        label.textColor            = .labelColor
        label.lineBreakMode        = .byWordWrapping
        label.maximumNumberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false

        let root = NSView()
        root.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: Self.hPad),
            label.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -Self.hPad),
            label.topAnchor.constraint(equalTo: root.topAnchor, constant: Self.vPad),
            label.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -Self.vPad)
        ])

        let vc   = NSViewController()
        vc.view  = root
        popover.contentViewController = vc
        popover.behavior = .transient
        popover.animates = true
    }

    // [EN] Show the popover next to `anchor` on the requested `edge`.
    //      - .maxY → bubble appears **above** the field, arrow points down  (Interval)
    //      - .minY → bubble appears **below** the field, arrow points up    (Duration)
    //      Measures the text first so the popover is exactly the right size.
    //      Any pending auto-dismiss timer is cancelled and reset.
    //
    // [CN] 在 `anchor` 的指定 `edge` 侧显示气泡。
    //      - .maxY → 气泡在输入框**正上方**，箭头朝下（间隔字段）
    //      - .minY → 气泡在输入框**正下方**，箭头朝上（停留时间字段）
    //      先测量文字尺寸以确保气泡恰好合身；取消并重置自动消失计时器。
    //
    // [JP] `anchor` の指定した `edge` 側にポップオーバーを表示する。
    //      - .maxY → フィールドの**真上**に気泡、矢印は下向き（間隔フィールド）
    //      - .minY → フィールドの**真下**に気泡、矢印は上向き（停留時間フィールド）
    //      テキストを先に計測してピッタリのサイズに調整し、タイマーをリセット。
    func show(message: String,
              anchoredTo anchor: NSView,
              preferredEdge edge: NSRectEdge,
              autoDismissAfter delay: TimeInterval = 3.0) {
        dismissItem?.cancel()
        label.stringValue = message

        let font        = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize, weight: .medium)
        let maxContentW = Self.maxWidth - Self.hPad * 2
        let measured    = (message as NSString).boundingRect(
            with: NSSize(width: maxContentW, height: 800),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: font])
        let bubbleW     = min(ceil(measured.width) + Self.hPad * 2, Self.maxWidth)
        let bubbleH     = ceil(measured.height) + Self.vPad * 2
        popover.contentSize = NSSize(width: bubbleW, height: bubbleH)

        if popover.isShown { popover.close() }
        popover.show(relativeTo: anchor.bounds, of: anchor, preferredEdge: edge)

        let item = DispatchWorkItem { [weak self] in self?.dismiss() }
        dismissItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
    }

    func dismiss() {
        dismissItem?.cancel()
        dismissItem = nil
        if popover.isShown { popover.close() }
    }
}

// MARK: - Position Matrix

private final class PositionMatrixControl: NSControl {

    var selectedPosition: Constants.OverlayPosition = .center {
        didSet { needsDisplay = true }
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: 260, height: 164)
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        applyShadow()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
    }

    // [EN] Re-snapshot the shadow CGColor whenever the system appearance flips.
    //      layer.shadowColor is a CGColor (static snapshot), so it must be
    //      refreshed explicitly on each appearance change to stay correct.
    // [CN] 系统外观切换时重新快照 shadow CGColor。
    //      layer.shadowColor 是静态 CGColor，每次 appearance 变化都需显式刷新。
    // [JP] システムの appearance が切り替わるたびに shadow の CGColor を再取得する。
    //      layer.shadowColor は静的な CGColor のため、明示的に更新が必要。
    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        applyShadow()
    }

    private func applyShadow() {
        layer?.shadowColor   = NSColor.shadowColor.withAlphaComponent(0.22).cgColor
        layer?.shadowOpacity = 1
        layer?.shadowRadius  = 8
        layer?.shadowOffset  = NSSize(width: 0, height: -2)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let screenRect = bounds.insetBy(dx: 16, dy: 16)
        let screenPath = NSBezierPath(roundedRect: screenRect, xRadius: 14, yRadius: 14)
        NSColor.controlBackgroundColor.setFill()
        screenPath.fill()
        // [EN] Add a subtle adaptive fill inside the border so the grid reads as a separate surface.
        // [CN] 在边框内部叠加轻微自适应底色，让九宫格成为独立的视觉区块。
        // [JP] 枠内に控えめな適応色を重ね、グリッドを独立した面として見せる。
        adaptiveGridOverlayColor().setFill()
        screenPath.fill()
        NSColor.separatorColor.setStroke()
        screenPath.lineWidth = 1
        screenPath.stroke()

        drawSubtleGrid(in: screenRect)

        for (position, point) in pointMap(in: screenRect) {
            let isSelected = position == selectedPosition
            let radius: CGFloat = isSelected ? 8 : 5
            let dotRect = NSRect(x: point.x - radius,
                                 y: point.y - radius,
                                 width: radius * 2,
                                 height: radius * 2)
            let dot = NSBezierPath(ovalIn: dotRect)
            (isSelected ? NSColor.controlAccentColor : NSColor.secondaryLabelColor).setFill()
            dot.fill()

            if isSelected {
                NSColor.controlAccentColor.withAlphaComponent(0.22).setFill()
                NSBezierPath(ovalIn: dotRect.insetBy(dx: -7, dy: -7)).fill()
            }
        }
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        let screenRect = bounds.insetBy(dx: 16, dy: 16)
        let nearest = pointMap(in: screenRect).min { lhs, rhs in
            distance(lhs.value, point) < distance(rhs.value, point)
        }

        if let position = nearest?.key {
            selectedPosition = position
            sendAction(action, to: target)
        }
    }

    private func drawSubtleGrid(in rect: NSRect) {
        NSColor.separatorColor.withAlphaComponent(0.45).setStroke()
        let path = NSBezierPath()
        for fraction in [CGFloat(1.0 / 3.0), CGFloat(2.0 / 3.0)] {
            let x = rect.minX + rect.width * fraction
            path.move(to: NSPoint(x: x, y: rect.minY + 8))
            path.line(to: NSPoint(x: x, y: rect.maxY - 8))

            let y = rect.minY + rect.height * fraction
            path.move(to: NSPoint(x: rect.minX + 8, y: y))
            path.line(to: NSPoint(x: rect.maxX - 8, y: y))
        }
        path.lineWidth = 0.5
        path.stroke()
    }

    private func adaptiveGridOverlayColor() -> NSColor {
        let appearance = effectiveAppearance.bestMatch(from: [.darkAqua, .aqua])
        if appearance == .darkAqua {
            return NSColor.white.withAlphaComponent(0.055)
        }
        return NSColor.black.withAlphaComponent(0.045)
    }

    private func pointMap(in rect: NSRect) -> [Constants.OverlayPosition: NSPoint] {
        [
            .topLeft: point(x: 0.12, y: 0.85, in: rect),
            .topCenter: point(x: 0.50, y: 0.85, in: rect),
            .topRight: point(x: 0.88, y: 0.85, in: rect),
            .middleLeft: point(x: 0.12, y: 0.50, in: rect),
            .center: point(x: 0.50, y: 0.50, in: rect),
            .middleRight: point(x: 0.88, y: 0.50, in: rect),
            .bottomLeft: point(x: 0.12, y: 0.15, in: rect),
            .bottomCenter: point(x: 0.50, y: 0.15, in: rect),
            .bottomRight: point(x: 0.88, y: 0.15, in: rect)
        ]
    }

    private func point(x: CGFloat, y: CGFloat, in rect: NSRect) -> NSPoint {
        NSPoint(x: rect.minX + rect.width * x,
                y: rect.minY + rect.height * y)
    }

    private func distance(_ a: NSPoint, _ b: NSPoint) -> CGFloat {
        hypot(a.x - b.x, a.y - b.y)
    }
}
