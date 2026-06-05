import AppKit

@MainActor
final class SettingsPopoverViewController: NSViewController {
    enum ValidationState {
        case idle
        case loading
        case success
        case failure
    }

    var onSaveToken: ((String) -> Void)?
    var onRefreshModels: (() -> Void)?
    var onModelChange: ((String) -> Void)?
    var onHotkeyChange: ((DictationHotkey) -> Void)?
    var onLanguageChange: ((AppLanguage) -> Void)?
    var onRequestPermissions: (() -> Void)?
    var onOpenLogs: (() -> Void)?
    var onLaunchAtLoginChange: ((Bool) -> Void)?
    var onHotkeyRecordingStateChange: ((Bool) -> Void)?

    private let savedToken: String
    private let selectedModel: String
    private let initialModels: [TranscriptionModel]
    private let initialHotkey: DictationHotkey
    private let initialLanguage: AppLanguage
    private let initialLaunchAtLogin: Bool
    private var language: AppLanguage
    private var currentModels: [TranscriptionModel] = []

    private let tokenField = PasteFriendlySecureTextField()
    private let validationImage = NSImageView()
    private let validationSpinner = NSProgressIndicator()
    private let saveButton = NSButton()
    private let languagePopup = NSPopUpButton()
    private let modelPopup = NSPopUpButton()
    private let refreshButton = NSButton()
    private let modelSpinner = NSProgressIndicator()
    private let hotkeyField = HotkeyRecorderField()
    private let launchAtLoginButton = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let statusLabel = NSTextField(labelWithString: "")
    private let titleLabel = NSTextField(labelWithString: "Dictation")
    private let languageLabel = NSTextField(labelWithString: "")
    private let languageHintLabel = NSTextField(labelWithString: "")
    private let tokenLabel = NSTextField(labelWithString: "")
    private let modelLabel = NSTextField(labelWithString: "")
    private let modelHintLabel = NSTextField(labelWithString: "")
    private let hotkeyLabel = NSTextField(labelWithString: "")
    private let resetHotkeyButton = NSButton()
    private let permissionsButton = NSButton()
    private let logsButton = NSButton()

    init(
        savedToken: String,
        selectedModel: String,
        models: [TranscriptionModel],
        hotkey: DictationHotkey,
        language: AppLanguage,
        launchAtLogin: Bool
    ) {
        self.savedToken = savedToken
        self.selectedModel = selectedModel
        self.initialModels = models
        self.initialHotkey = hotkey
        self.initialLanguage = language
        self.language = language
        self.initialLaunchAtLogin = launchAtLogin
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 520, height: 500))
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        preferredContentSize = NSSize(width: 520, height: 500)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        buildUI()
        setValidationState(savedToken.isEmpty ? .idle : .success)
        setModels(initialModels, selectedModel: selectedModel)
        hotkeyField.hotkey = initialHotkey
        hotkeyField.language = initialLanguage
        selectLanguage(initialLanguage)
        setLaunchAtLogin(initialLaunchAtLogin)
        applyLocalization()
    }

    func setStatus(_ value: String) {
        let singleLine = value.replacingOccurrences(of: "\n", with: " ")
        if singleLine.count > 220 {
            statusLabel.stringValue = "\(singleLine.prefix(217))..."
        } else {
            statusLabel.stringValue = singleLine
        }
    }

    func setValidationState(_ state: ValidationState) {
        validationSpinner.stopAnimation(nil)
        validationSpinner.isHidden = true
        validationImage.isHidden = false

        switch state {
        case .idle:
            validationImage.image = NSImage(systemSymbolName: "circle", accessibilityDescription: AppText.validationUnchecked(language))
            validationImage.contentTintColor = .tertiaryLabelColor
        case .loading:
            validationImage.isHidden = true
            validationSpinner.isHidden = false
            validationSpinner.startAnimation(nil)
        case .success:
            validationImage.image = NSImage(systemSymbolName: "checkmark.circle.fill", accessibilityDescription: AppText.validationAccepted(language))
            validationImage.contentTintColor = .systemGreen
        case .failure:
            validationImage.image = NSImage(systemSymbolName: "xmark.circle.fill", accessibilityDescription: AppText.validationFailed(language))
            validationImage.contentTintColor = .systemRed
        }
    }

    func setModels(_ models: [TranscriptionModel], selectedModel: String) {
        currentModels = models
        modelPopup.removeAllItems()
        for model in models {
            modelPopup.addItem(withTitle: "\(model.id)  ·  \(AppText.modelBadge(model.badge, language: language))")
            modelPopup.lastItem?.representedObject = model.id
        }
        selectModel(selectedModel)
    }

    func selectModel(_ model: String) {
        if let item = modelPopup.itemArray.first(where: { $0.representedObject as? String == model }) {
            modelPopup.select(item)
        } else if modelPopup.numberOfItems > 0 {
            modelPopup.selectItem(at: 0)
        }
        modelChanged()
    }

    func setModelsLoading(_ loading: Bool) {
        if loading {
            modelSpinner.isHidden = false
            modelSpinner.startAnimation(nil)
        } else {
            modelSpinner.stopAnimation(nil)
            modelSpinner.isHidden = true
        }
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        launchAtLoginButton.state = enabled ? .on : .off
    }

    func selectLanguage(_ selectedLanguage: AppLanguage) {
        if let item = languagePopup.itemArray.first(where: { $0.representedObject as? String == selectedLanguage.rawValue }) {
            languagePopup.select(item)
        }
    }

    private func buildUI() {
        let headerIcon = NSImageView()
        headerIcon.image = NSImage(systemSymbolName: "laptopcomputer.and.mic", accessibilityDescription: "Dictation")
            ?? NSImage(systemSymbolName: "mic.fill", accessibilityDescription: "Dictation")
        headerIcon.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 22, weight: .medium)
        headerIcon.contentTintColor = .controlAccentColor
        headerIcon.translatesAutoresizingMaskIntoConstraints = false
        headerIcon.widthAnchor.constraint(equalToConstant: 28).isActive = true

        titleLabel.font = .boldSystemFont(ofSize: 24)

        let header = NSStackView(views: [headerIcon, titleLabel])
        header.orientation = .horizontal
        header.alignment = .centerY
        header.spacing = 9

        configureSectionLabel(languageLabel)
        configureHintLabel(languageHintLabel)
        languagePopup.target = self
        languagePopup.action = #selector(languageChanged)
        languagePopup.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        languagePopup.removeAllItems()
        for appLanguage in AppLanguage.allCases {
            languagePopup.addItem(withTitle: appLanguage.displayName)
            languagePopup.lastItem?.representedObject = appLanguage.rawValue
        }

        configureSectionLabel(tokenLabel)
        tokenField.placeholderString = "sk-..."
        tokenField.stringValue = savedToken
        tokenField.bezelStyle = .roundedBezel
        tokenField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        validationSpinner.style = .spinning
        validationSpinner.controlSize = .small
        validationSpinner.isDisplayedWhenStopped = false
        validationSpinner.isHidden = true
        validationImage.imageScaling = .scaleProportionallyDown

        let validationBox = NSView()
        validationBox.translatesAutoresizingMaskIntoConstraints = false
        validationBox.addSubview(validationImage)
        validationBox.addSubview(validationSpinner)
        validationImage.translatesAutoresizingMaskIntoConstraints = false
        validationSpinner.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            validationBox.widthAnchor.constraint(equalToConstant: 22),
            validationBox.heightAnchor.constraint(equalToConstant: 22),
            validationImage.centerXAnchor.constraint(equalTo: validationBox.centerXAnchor),
            validationImage.centerYAnchor.constraint(equalTo: validationBox.centerYAnchor),
            validationImage.widthAnchor.constraint(equalToConstant: 18),
            validationImage.heightAnchor.constraint(equalToConstant: 18),
            validationSpinner.centerXAnchor.constraint(equalTo: validationBox.centerXAnchor),
            validationSpinner.centerYAnchor.constraint(equalTo: validationBox.centerYAnchor),
            validationSpinner.widthAnchor.constraint(equalToConstant: 18),
            validationSpinner.heightAnchor.constraint(equalToConstant: 18)
        ])

        saveButton.bezelStyle = .rounded
        saveButton.target = self
        saveButton.action = #selector(saveToken)
        saveButton.translatesAutoresizingMaskIntoConstraints = false
        saveButton.setContentHuggingPriority(.required, for: .horizontal)
        saveButton.widthAnchor.constraint(equalToConstant: 112).isActive = true

        let tokenRow = NSStackView(views: [tokenField, validationBox, saveButton])
        tokenRow.orientation = .horizontal
        tokenRow.alignment = .centerY
        tokenRow.spacing = 8
        tokenField.setContentHuggingPriority(.defaultLow, for: .horizontal)
        tokenField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        configureSectionLabel(modelLabel)
        configureIconButton(refreshButton, symbol: "arrow.clockwise", action: #selector(refreshModels), accessibilityDescription: AppText.refreshModels(language))
        modelSpinner.style = .spinning
        modelSpinner.controlSize = .small
        modelSpinner.isHidden = true

        let modelHeader = NSStackView(views: [modelLabel, NSView(), modelSpinner, refreshButton])
        modelHeader.orientation = .horizontal
        modelHeader.alignment = .centerY
        modelHeader.spacing = 6

        modelPopup.target = self
        modelPopup.action = #selector(modelChanged)
        modelPopup.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        configureHintLabel(modelHintLabel)

        resetHotkeyButton.bezelStyle = .rounded
        resetHotkeyButton.target = self
        resetHotkeyButton.action = #selector(resetHotkey)
        hotkeyField.onCapture = { [weak self] hotkey in
            self?.onHotkeyChange?(hotkey)
        }
        hotkeyField.onInvalidCapture = { [weak self] reason in
            self?.setStatus(reason)
        }
        hotkeyField.onRecordingStateChange = { [weak self] isRecording in
            self?.onHotkeyRecordingStateChange?(isRecording)
            if isRecording {
                guard let self else { return }
                self.setStatus(AppText.hotkeyCaptureHelp(self.language))
            }
        }

        let hotkeyRow = NSStackView(views: [hotkeyField, resetHotkeyButton])
        hotkeyRow.orientation = .horizontal
        hotkeyRow.alignment = .centerY
        hotkeyRow.spacing = 8

        configureRowButton(permissionsButton, symbol: "checkmark.shield", action: #selector(requestPermissions))
        configureRowButton(logsButton, symbol: "doc.text.magnifyingglass", action: #selector(openLogs))
        launchAtLoginButton.target = self
        launchAtLoginButton.action = #selector(launchAtLoginChanged)

        statusLabel.font = .systemFont(ofSize: 12)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.maximumNumberOfLines = 1
        statusLabel.lineBreakMode = .byTruncatingTail
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        statusLabel.heightAnchor.constraint(equalToConstant: 34).isActive = true

        let stack = NSStackView(views: [
            header,
            languageLabel,
            languagePopup,
            languageHintLabel,
            tokenLabel,
            tokenRow,
            modelHeader,
            modelPopup,
            modelHintLabel,
            hotkeyLabel,
            hotkeyRow,
            separator(),
            permissionsButton,
            logsButton,
            launchAtLoginButton,
            statusLabel
        ])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            stack.topAnchor.constraint(equalTo: view.topAnchor, constant: 24),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: view.bottomAnchor, constant: -24),
            languagePopup.widthAnchor.constraint(equalTo: stack.widthAnchor),
            tokenRow.widthAnchor.constraint(equalTo: stack.widthAnchor),
            modelHeader.widthAnchor.constraint(equalTo: stack.widthAnchor),
            modelPopup.widthAnchor.constraint(equalTo: stack.widthAnchor),
            hotkeyRow.widthAnchor.constraint(equalTo: stack.widthAnchor),
            permissionsButton.widthAnchor.constraint(equalTo: stack.widthAnchor),
            logsButton.widthAnchor.constraint(equalTo: stack.widthAnchor),
            launchAtLoginButton.widthAnchor.constraint(equalTo: stack.widthAnchor),
            statusLabel.widthAnchor.constraint(equalTo: stack.widthAnchor)
        ])
    }

    private func sectionLabel(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        configureSectionLabel(label)
        return label
    }

    private func configureSectionLabel(_ label: NSTextField) {
        label.font = .systemFont(ofSize: 12, weight: .medium)
    }

    private func hintLabel(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        configureHintLabel(label)
        return label
    }

    private func configureHintLabel(_ label: NSTextField) {
        label.font = .systemFont(ofSize: 11)
        label.textColor = .secondaryLabelColor
    }

    private func separator() -> NSBox {
        let separator = NSBox()
        separator.boxType = .separator
        return separator
    }

    private func iconButton(_ symbol: String, action: Selector, accessibilityDescription: String) -> NSButton {
        let button = NSButton()
        configureIconButton(button, symbol: symbol, action: action, accessibilityDescription: accessibilityDescription)
        return button
    }

    private func configureIconButton(_ button: NSButton, symbol: String, action: Selector, accessibilityDescription: String) {
        button.image = NSImage(systemSymbolName: symbol, accessibilityDescription: accessibilityDescription)
        button.imagePosition = .imageOnly
        button.bezelStyle = .rounded
        button.target = self
        button.action = action
    }

    private func rowButton(_ title: String, symbol: String, action: Selector) -> NSButton {
        let button = NSButton(title: title, target: self, action: action)
        configureRowButton(button, symbol: symbol, action: action)
        return button
    }

    private func configureRowButton(_ button: NSButton, symbol: String, action: Selector) {
        button.image = NSImage(systemSymbolName: symbol, accessibilityDescription: button.title)
        button.imagePosition = .imageLeading
        button.alignment = .left
        button.bezelStyle = .rounded
        button.target = self
        button.action = action
    }

    private func applyLocalization() {
        languageLabel.stringValue = AppText.languageLabel(language)
        languageHintLabel.stringValue = AppText.languageHint(language)
        tokenLabel.stringValue = AppText.apiKeyLabel(language)
        saveButton.title = AppText.save(language)
        modelLabel.stringValue = AppText.transcriptionModel(language)
        refreshButton.image = NSImage(systemSymbolName: "arrow.clockwise", accessibilityDescription: AppText.refreshModels(language))
        modelHintLabel.stringValue = AppText.modelHint(language)
        hotkeyLabel.stringValue = AppText.hotkeyLabel(language)
        resetHotkeyButton.title = AppText.reset(language)
        permissionsButton.title = AppText.permissions(language)
        permissionsButton.image = NSImage(systemSymbolName: "checkmark.shield", accessibilityDescription: AppText.permissions(language))
        logsButton.title = AppText.logs(language)
        logsButton.image = NSImage(systemSymbolName: "doc.text.magnifyingglass", accessibilityDescription: AppText.logs(language))
        launchAtLoginButton.title = AppText.launchAtLogin(language)
        hotkeyField.language = language

        if let selectedModel = modelPopup.selectedItem?.representedObject as? String, !currentModels.isEmpty {
            setModels(currentModels, selectedModel: selectedModel)
        }
    }

    @objc private func saveToken() {
        onSaveToken?(tokenField.stringValue)
    }

    @objc private func refreshModels() {
        onRefreshModels?()
    }

    @objc private func modelChanged() {
        guard let id = modelPopup.selectedItem?.representedObject as? String else { return }
        onModelChange?(id)
    }

    @objc private func languageChanged() {
        guard
            let rawValue = languagePopup.selectedItem?.representedObject as? String,
            let selectedLanguage = AppLanguage(rawValue: rawValue)
        else {
            return
        }

        language = selectedLanguage
        applyLocalization()
        onLanguageChange?(selectedLanguage)
    }

    @objc private func resetHotkey() {
        hotkeyField.hotkey = .defaultHotkey
        onHotkeyChange?(.defaultHotkey)
    }

    @objc private func requestPermissions() {
        onRequestPermissions?()
    }

    @objc private func openLogs() {
        onOpenLogs?()
    }

    @objc private func launchAtLoginChanged() {
        onLaunchAtLoginChange?(launchAtLoginButton.state == .on)
    }
}
