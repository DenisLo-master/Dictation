import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let settings = AppSettings()
    private let logger = AppLogger()
    private let overlay = EqualizerOverlayController()
    private let modelService = OpenAIModelService()
    private lazy var dictationController = DictationController(
        settings: settings,
        overlay: overlay,
        logger: logger
    )

    private let popover = NSPopover()
    private var statusItem: NSStatusItem?
    private var settingsViewController: SettingsPopoverViewController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        try? AppPaths.prepare()
        logger.log(.info, "app_launched")
        configureApplicationMenu()
        configureStatusItem()
        configurePopover()
        dictationController.onStatusChange = { [weak self] status in
            self?.settingsViewController?.setStatus(status)
        }
        dictationController.startHotkeyMonitoring()
        dictationController.processPendingRecordings()
        settingsViewController?.setStatus("Готово. Удерживайте \(settings.hotkey.displayName) для диктовки.")
    }

    private func configureStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = NSImage(systemSymbolName: "mic.fill", accessibilityDescription: "Dictation")
        item.button?.imagePosition = .imageOnly
        item.button?.target = self
        item.button?.action = #selector(togglePopover(_:))
        statusItem = item
    }

    private func configurePopover() {
        let controller = SettingsPopoverViewController(
            savedToken: settings.apiKey ?? "",
            selectedModel: settings.model,
            models: OpenAIModelService.fallbackModels,
            hotkey: settings.hotkey,
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
            self?.settingsViewController?.setStatus("Клавиша диктовки: \(hotkey.displayName).")
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
        controller.onQuit = {
            NSApp.terminate(nil)
        }

        popover.behavior = .transient
        popover.contentSize = NSSize(width: 370, height: 462)
        popover.contentViewController = controller
        settingsViewController = controller

        if settings.apiKey?.isEmpty == false {
            refreshModels(controller: controller, silent: true)
        }
    }

    private func configureApplicationMenu() {
        let mainMenu = NSMenu()

        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "Quit Dictation", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)

        let editMenuItem = NSMenuItem()
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editMenuItem.submenu = editMenu
        mainMenu.addItem(editMenuItem)

        NSApp.mainMenu = mainMenu
    }

    private func saveAndValidateToken(_ token: String, controller: SettingsPopoverViewController?) {
        let trimmedToken = token.trimmingCharacters(in: .whitespacesAndNewlines)
        controller?.setValidationState(.loading)
        controller?.setStatus("Проверяю токен...")

        Task {
            do {
                guard !trimmedToken.isEmpty else {
                    try settings.saveAPIKey("")
                    controller?.setValidationState(.idle)
                    controller?.setStatus("Токен очищен.")
                    logger.log(.info, "token_cleared")
                    return
                }

                let models = try await modelService.fetchTranscriptionModels(apiKey: trimmedToken)
                try settings.saveAPIKey(trimmedToken)
                controller?.setModels(models, selectedModel: settings.model)
                controller?.setValidationState(.success)
                controller?.setStatus("Токен принят. Модели загружены онлайн.")
                logger.log(.info, "token_validated", metadata: ["models": "\(models.count)"])
            } catch {
                controller?.setValidationState(.failure)
                controller?.setStatus("Токен не прошел проверку: \(error.localizedDescription)")
                logger.log(.error, "token_validation_failed", metadata: ["message": error.localizedDescription])
            }
        }
    }

    private func refreshModels(controller: SettingsPopoverViewController?, silent: Bool = false) {
        guard let apiKey = settings.apiKey, !apiKey.isEmpty else {
            controller?.setModels(OpenAIModelService.fallbackModels, selectedModel: settings.model)
            if !silent {
                controller?.setStatus("Сначала сохраните OpenAI API key.")
            }
            return
        }

        if !silent {
            controller?.setStatus("Загружаю модели онлайн...")
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
                    controller?.setStatus("Модели обновлены из OpenAI.")
                }
                logger.log(.info, "models_refreshed", metadata: ["count": "\(models.count)"])
            } catch {
                controller?.setModels(OpenAIModelService.fallbackModels, selectedModel: settings.model)
                if !silent {
                    controller?.setStatus("Не удалось загрузить модели: \(error.localizedDescription)")
                }
                logger.log(.warning, "models_refresh_failed", metadata: ["message": error.localizedDescription])
            }
        }
    }

    private func setLaunchAtLogin(_ enabled: Bool, controller: SettingsPopoverViewController?) {
        do {
            try LaunchAtLoginController.setEnabled(enabled)
            controller?.setLaunchAtLogin(LaunchAtLoginController.isEnabled)
            controller?.setStatus(enabled ? "Автозапуск включен." : "Автозапуск выключен.")
            logger.log(.info, "launch_at_login_changed", metadata: ["enabled": "\(enabled)"])
        } catch {
            controller?.setLaunchAtLogin(LaunchAtLoginController.isEnabled)
            controller?.setStatus("Не удалось изменить автозапуск: \(error.localizedDescription)")
            logger.log(.error, "launch_at_login_failed", metadata: ["message": error.localizedDescription])
        }
    }

    @objc private func togglePopover(_ sender: AnyObject?) {
        guard let button = statusItem?.button else { return }

        if popover.isShown {
            popover.performClose(sender)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}
