import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private static let settingsWindowSize = NSSize(width: 520, height: 500)

    private let settings = AppSettings()
    private let logger = AppLogger()
    private let overlay = EqualizerOverlayController()
    private let modelService = OpenAIModelService()
    private lazy var dictationController = DictationController(
        settings: settings,
        overlay: overlay,
        logger: logger
    )

    private var statusItem: NSStatusItem?
    private var settingsViewController: SettingsPopoverViewController?
    private var settingsWindowController: NSWindowController?
    private var settingsMenuItem: NSMenuItem?
    private var aboutMenuItem: NSMenuItem?
    private var quitMenuItem: NSMenuItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        try? AppPaths.prepare()
        logger.log(.info, "app_launched")
        configureApplicationMenu()
        configureStatusItem()
        dictationController.onStatusChange = { [weak self] status in
            self?.settingsViewController?.setStatus(status)
        }
        dictationController.startHotkeyMonitoring()
        dictationController.discardPendingRecordings()
    }

    private func configureStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "mic.fill", accessibilityDescription: "Dictation")
        item.button?.title = item.button?.image == nil ? "D" : ""

        let menu = NSMenu()
        let settingsItem = menuItem(AppText.settings(settings.language), action: #selector(openSettings), keyEquivalent: ",")
        let aboutItem = menuItem(AppText.about(settings.language), action: #selector(openAbout), keyEquivalent: "")
        let quitItem = menuItem(AppText.quit(settings.language), action: #selector(quit), keyEquivalent: "q")
        menu.addItem(settingsItem)
        menu.addItem(aboutItem)
        menu.addItem(.separator())
        menu.addItem(quitItem)
        item.menu = menu

        statusItem = item
        settingsMenuItem = settingsItem
        aboutMenuItem = aboutItem
        quitMenuItem = quitItem
    }

    private func menuItem(_ title: String, action: Selector, keyEquivalent: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: keyEquivalent)
        item.target = self
        return item
    }

    private func makeSettingsViewController() -> SettingsPopoverViewController {
        let controller = SettingsPopoverViewController(
            savedToken: settings.apiKey ?? "",
            selectedModel: settings.model,
            models: OpenAIModelService.fallbackModels,
            hotkey: settings.hotkey,
            language: settings.language,
            launchAtLogin: LaunchAtLoginController.isEnabled
        )

        controller.onSaveToken = { [weak self, weak controller] token in
            self?.saveAndValidateToken(token, controller: controller)
        }
        controller.onRefreshModels = { [weak self, weak controller] in
            self?.refreshModels(controller: controller)
        }
        controller.onModelChange = { [weak self] model in
            self?.settings.model = model
            self?.logger.log(.info, "model_selected", metadata: ["model": model])
        }
        controller.onHotkeyChange = { [weak self] hotkey in
            self?.settings.hotkey = hotkey
            self?.logger.log(.info, "hotkey_changed", metadata: ["hotkey": hotkey.displayName])
            let language = self?.settings.language ?? .defaultLanguage
            self?.settingsViewController?.setStatus(AppText.hotkeyChanged(hotkey.displayName, language: language))
        }
        controller.onLanguageChange = { [weak self, weak controller] language in
            self?.settings.language = language
            self?.configureApplicationMenu()
            self?.settingsViewController?.setStatus(AppText.ready(hotkey: self?.settings.hotkey.displayName ?? "", language: language))
            self?.logger.log(.info, "language_changed", metadata: ["language": language.rawValue])
            if self?.settings.apiKey?.isEmpty == false {
                self?.refreshModels(controller: controller, silent: true)
            }
        }
        controller.onHotkeyRecordingStateChange = { [weak self] isRecording in
            self?.dictationController.setHotkeyCaptureActive(isRecording)
        }
        controller.onRequestPermissions = { [weak self] in
            self?.dictationController.requestPermissions()
        }
        controller.onOpenLogs = { [weak self] in
            self?.logger.openLogFile()
        }
        controller.onLaunchAtLoginChange = { [weak self, weak controller] enabled in
            self?.setLaunchAtLogin(enabled, controller: controller)
        }

        if settings.apiKey?.isEmpty == false {
            refreshModels(controller: controller, silent: true)
        }

        return controller
    }

    private func configureSettingsWindowIfNeeded() {
        guard settingsWindowController == nil else { return }

        let controller = makeSettingsViewController()
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: Self.settingsWindowSize),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = AppText.settings(settings.language)
        window.contentViewController = controller
        window.contentMinSize = Self.settingsWindowSize
        window.contentMaxSize = Self.settingsWindowSize
        window.minSize = window.frameRect(forContentRect: NSRect(origin: .zero, size: Self.settingsWindowSize)).size
        window.maxSize = window.minSize
        window.center()
        window.isReleasedWhenClosed = false

        settingsViewController = controller
        settingsWindowController = NSWindowController(window: window)
        controller.setStatus(AppText.ready(hotkey: settings.hotkey.displayName, language: settings.language))
    }

    private func configureApplicationMenu() {
        let mainMenu = NSMenu()
        let language = settings.language

        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: AppText.quitApp(language), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)

        let editMenuItem = NSMenuItem()
        let editMenu = NSMenu(title: AppText.editMenu(language))
        editMenu.addItem(withTitle: AppText.cut(language), action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: AppText.copy(language), action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: AppText.paste(language), action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(withTitle: AppText.selectAll(language), action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editMenuItem.submenu = editMenu
        mainMenu.addItem(editMenuItem)

        NSApp.mainMenu = mainMenu
        applyStatusMenuLocalization()
    }

    private func saveAndValidateToken(_ token: String, controller: SettingsPopoverViewController?) {
        let trimmedToken = token.trimmingCharacters(in: .whitespacesAndNewlines)
        controller?.setValidationState(.loading)
        controller?.setStatus(AppText.checkingToken(settings.language))

        Task {
            do {
                guard !trimmedToken.isEmpty else {
                    try settings.saveAPIKey("")
                    controller?.setValidationState(.idle)
                    controller?.setStatus(AppText.tokenCleared(settings.language))
                    logger.log(.info, "token_cleared")
                    return
                }

                try settings.saveAPIKey(trimmedToken)
                let models = try await modelService.fetchTranscriptionModels(apiKey: trimmedToken)
                controller?.setModels(models, selectedModel: settings.model)
                controller?.setValidationState(.success)
                controller?.setStatus(AppText.tokenAcceptedModelsLoaded(settings.language))
                logger.log(.info, "token_validated", metadata: ["models": "\(models.count)"])
            } catch {
                controller?.setValidationState(.failure)
                controller?.setStatus(AppText.tokenValidationFailed(error.localizedDescription, language: settings.language))
                logger.log(.error, "token_validation_failed", metadata: ["message": error.localizedDescription])
            }
        }
    }

    private func refreshModels(controller: SettingsPopoverViewController?, silent: Bool = false) {
        guard let apiKey = settings.apiKey, !apiKey.isEmpty else {
            controller?.setModels(OpenAIModelService.fallbackModels, selectedModel: settings.model)
            if !silent {
                controller?.setStatus(AppText.saveTokenFirst(settings.language))
            }
            return
        }

        if !silent {
            controller?.setStatus(AppText.loadingModels(settings.language))
        }
        controller?.setModelsLoading(true)

        Task {
            defer { controller?.setModelsLoading(false) }

            do {
                let models = try await modelService.fetchTranscriptionModels(apiKey: apiKey)
                controller?.setModels(models, selectedModel: settings.model)
                if !models.contains(where: { $0.id == settings.model }), let first = models.first {
                    settings.model = first.id
                    controller?.selectModel(first.id)
                }
                if !silent {
                    controller?.setStatus(AppText.modelsUpdated(settings.language))
                }
                logger.log(.info, "models_refreshed", metadata: ["count": "\(models.count)"])
            } catch {
                controller?.setModels(OpenAIModelService.fallbackModels, selectedModel: settings.model)
                if !silent {
                    controller?.setStatus(AppText.modelsLoadFailed(error.localizedDescription, language: settings.language))
                }
                logger.log(.warning, "models_refresh_failed", metadata: ["message": error.localizedDescription])
            }
        }
    }

    private func setLaunchAtLogin(_ enabled: Bool, controller: SettingsPopoverViewController?) {
        do {
            try LaunchAtLoginController.setEnabled(enabled)
            controller?.setLaunchAtLogin(LaunchAtLoginController.isEnabled)
            controller?.setStatus(AppText.launchAtLoginChanged(enabled, language: settings.language))
            logger.log(.info, "launch_at_login_changed", metadata: ["enabled": "\(enabled)"])
        } catch {
            controller?.setLaunchAtLogin(LaunchAtLoginController.isEnabled)
            controller?.setStatus(AppText.launchAtLoginFailed(error.localizedDescription, language: settings.language))
            logger.log(.error, "launch_at_login_failed", metadata: ["message": error.localizedDescription])
        }
    }

    private func applyStatusMenuLocalization() {
        let language = settings.language
        settingsMenuItem?.title = AppText.settings(language)
        aboutMenuItem?.title = AppText.about(language)
        quitMenuItem?.title = AppText.quit(language)
        settingsWindowController?.window?.title = AppText.settings(language)
    }

    @objc private func openSettings() {
        configureSettingsWindowIfNeeded()
        NSApp.activate(ignoringOtherApps: true)
        settingsWindowController?.showWindow(nil)
    }

    @objc private func openAbout() {
        let language = settings.language
        let alert = NSAlert()
        alert.messageText = AppText.about(language)
        alert.informativeText = AppText.aboutMessage(
            version: AppMetadata.version(),
            developerEmail: AppMetadata.developerEmail,
            language: language
        )
        alert.alertStyle = .informational
        alert.addButton(withTitle: AppText.ok(language))
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
