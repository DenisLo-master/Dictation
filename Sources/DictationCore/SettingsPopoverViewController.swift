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
    var onRequestPermissions: (() -> Void)?
    var onOpenLogs: (() -> Void)?
    var onLaunchAtLoginChange: ((Bool) -> Void)?
    var onQuit: (() -> Void)?

    private let savedToken: String
    private let selectedModel: String
    private let initialModels: [TranscriptionModel]
    private let initialHotkey: DictationHotkey
    private let initialLaunchAtLogin: Bool

    private let tokenField = NSSecureTextField()
    private let validationImage = NSImageView()
    private let validationSpinner = NSProgressIndicator()
    private let saveButton = NSButton()
    private let modelPopup = NSPopUpButton()
    private let modelSpinner = NSProgressIndicator()
    private let hotkeyField = HotkeyRecorderField()
    private let launchAtLoginButton = NSButton(checkboxWithTitle: "Запускать при входе", target: nil, action: nil)
    private let statusLabel = NSTextField(labelWithString: "")

    init(
        savedToken: String,
        selectedModel: String,
        models: [TranscriptionModel],
        hotkey: DictationHotkey,
        launchAtLogin: Bool
    ) {
        self.savedToken = savedToken
        self.selectedModel = selectedModel
        self.initialModels = models
        self.initialHotkey = hotkey
        self.initialLaunchAtLogin = launchAtLogin
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 370, height: 462))
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        buildUI()
        setValidationState(savedToken.isEmpty ? .idle : .success)
        setModels(initialModels, selectedModel: selectedModel)
        hotkeyField.hotkey = initialHotkey
        setLaunchAtLogin(initialLaunchAtLogin)
    }

    func setStatus(_ value: String) {
        statusLabel.stringValue = value
    }

    func setValidationState(_ state: ValidationState) {
        validationSpinner.stopAnimation(nil)
        validationSpinner.isHidden = true
        validationImage.isHidden = false

        switch state {
        case .idle:
            validationImage.image = NSImage(systemSymbolName: "circle", accessibilityDescription: "Не проверено")
            validationImage.contentTintColor = .tertiaryLabelColor
        case .loading:
            validationImage.isHidden = true
            validationSpinner.isHidden = false
            validationSpinner.startAnimation(nil)
        case .success:
            validationImage.image = NSImage(systemSymbolName: "checkmark.circle.fill", accessibilityDescription: "Токен принят")
            validationImage.contentTintColor = .systemGreen
        case .failure:
            validationImage.image = NSImage(systemSymbolName: "xmark.circle.fill", accessibilityDescription: "Ошибка токена")
            validationImage.contentTintColor = .systemRed
        }
    }

    func setModels(_ models: [TranscriptionModel], selectedModel: String) {
        modelPopup.removeAllItems()
        for model in models {
            modelPopup.addItem(withTitle: "\(model.id)  ·  \(model.badge)")
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

    private func buildUI() {
        let headerIcon = NSImageView()
        headerIcon.image = NSImage(systemSymbolName: "laptopcomputer.and.mic", accessibilityDescription: "Dictation")
            ?? NSImage(systemSymbolName: "mic.fill", accessibilityDescription: "Dictation")
        headerIcon.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 22, weight: .medium)
        headerIcon.contentTintColor = .controlAccentColor

        let title = NSTextField(labelWithString: "Dictation")
        title.font = .systemFont(ofSize: 18, weight: .semibold)

        let header = NSStackView(views: [headerIcon, title])
        header.orientation = .horizontal
        header.alignment = .centerY
        header.spacing = 9

        let tokenLabel = sectionLabel("OpenAI API Key")
        tokenField.placeholderString = "sk-..."
        tokenField.stringValue = savedToken
        tokenField.bezelStyle = .roundedBezel

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

        saveButton.title = "Сохранить"
        saveButton.bezelStyle = .rounded
        saveButton.target = self
        saveButton.action = #selector(saveToken)

        let tokenRow = NSStackView(views: [tokenField, validationBox, saveButton])
        tokenRow.orientation = .horizontal
        tokenRow.alignment = .centerY
        tokenRow.spacing = 8
        tokenField.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let modelLabel = sectionLabel("Модель транскрипции")
        let refreshButton = iconButton("arrow.clockwise", action: #selector(refreshModels), accessibilityDescription: "Обновить модели")
        modelSpinner.style = .spinning
        modelSpinner.controlSize = .small
        modelSpinner.isHidden = true

        let modelHeader = NSStackView(views: [modelLabel, NSView(), modelSpinner, refreshButton])
        modelHeader.orientation = .horizontal
        modelHeader.alignment = .centerY
        modelHeader.spacing = 6

        modelPopup.target = self
        modelPopup.action = #selector(modelChanged)
        let modelHint = hintLabel("список загружается онлайн через OpenAI Models API")

        let hotkeyLabel = sectionLabel("Клавиша диктовки")
        let resetHotkeyButton = NSButton(title: "Сбросить", target: self, action: #selector(resetHotkey))
        resetHotkeyButton.bezelStyle = .rounded
        hotkeyField.onCapture = { [weak self] hotkey in
            self?.onHotkeyChange?(hotkey)
        }
        hotkeyField.onInvalidCapture = { [weak self] reason in
            self?.setStatus(reason)
        }

        let hotkeyRow = NSStackView(views: [hotkeyField, resetHotkeyButton])
        hotkeyRow.orientation = .horizontal
        hotkeyRow.alignment = .centerY
        hotkeyRow.spacing = 8

        let permissionsButton = rowButton("Разрешения", symbol: "checkmark.shield", action: #selector(requestPermissions))
        let logsButton = rowButton("Логи", symbol: "doc.text.magnifyingglass", action: #selector(openLogs))
        launchAtLoginButton.target = self
        launchAtLoginButton.action = #selector(launchAtLoginChanged)

        let quitButton = rowButton("Выход", symbol: "power", action: #selector(quit))

        statusLabel.font = .systemFont(ofSize: 12)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.maximumNumberOfLines = 2
        statusLabel.lineBreakMode = .byWordWrapping

        let metadataLabel = hintLabel(AppMetadata.footerText())
        metadataLabel.maximumNumberOfLines = 2
        metadataLabel.lineBreakMode = .byWordWrapping

        let stack = NSStackView(views: [
            header,
            tokenLabel,
            tokenRow,
            modelHeader,
            modelPopup,
            modelHint,
            hotkeyLabel,
            hotkeyRow,
            separator(),
            permissionsButton,
            logsButton,
            launchAtLoginButton,
            quitButton,
            statusLabel,
            separator(),
            metadataLabel
        ])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 9
        stack.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 18),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -18),
            stack.topAnchor.constraint(equalTo: view.topAnchor, constant: 18),
            tokenRow.widthAnchor.constraint(equalTo: stack.widthAnchor),
            modelHeader.widthAnchor.constraint(equalTo: stack.widthAnchor),
            modelPopup.widthAnchor.constraint(equalTo: stack.widthAnchor),
            hotkeyRow.widthAnchor.constraint(equalTo: stack.widthAnchor),
            permissionsButton.widthAnchor.constraint(equalTo: stack.widthAnchor),
            logsButton.widthAnchor.constraint(equalTo: stack.widthAnchor),
            launchAtLoginButton.widthAnchor.constraint(equalTo: stack.widthAnchor),
            quitButton.widthAnchor.constraint(equalTo: stack.widthAnchor),
            statusLabel.widthAnchor.constraint(equalTo: stack.widthAnchor),
            metadataLabel.widthAnchor.constraint(equalTo: stack.widthAnchor)
        ])
    }

    private func sectionLabel(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = .systemFont(ofSize: 12, weight: .medium)
        return label
    }

    private func hintLabel(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = .systemFont(ofSize: 11)
        label.textColor = .secondaryLabelColor
        return label
    }

    private func separator() -> NSBox {
        let separator = NSBox()
        separator.boxType = .separator
        return separator
    }

    private func iconButton(_ symbol: String, action: Selector, accessibilityDescription: String) -> NSButton {
        let button = NSButton()
        button.image = NSImage(systemSymbolName: symbol, accessibilityDescription: accessibilityDescription)
        button.imagePosition = .imageOnly
        button.bezelStyle = .rounded
        button.target = self
        button.action = action
        return button
    }

    private func rowButton(_ title: String, symbol: String, action: Selector) -> NSButton {
        let button = NSButton(title: title, target: self, action: action)
        button.image = NSImage(systemSymbolName: symbol, accessibilityDescription: title)
        button.imagePosition = .imageLeading
        button.alignment = .left
        button.bezelStyle = .rounded
        return button
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

    @objc private func quit() {
        onQuit?()
    }
}
