import AppKit
import ApplicationServices
import Carbon

@MainActor
final class PasteInjector {
    enum PasteError: LocalizedError {
        case accessibilityPermissionMissing
        case focusedTextInputMissing

        var errorDescription: String? {
            switch self {
            case .accessibilityPermissionMissing:
                "Для вставки текста в другое приложение нужен Accessibility-доступ."
            case .focusedTextInputMissing:
                "Активное поле ввода не найдено."
            }
        }
    }

    private struct PasteboardSnapshot {
        let items: [[NSPasteboard.PasteboardType: Data]]
    }

    private var lastSettingsOpenAt: Date?

    func requestAccessibilityPermission(openSettings: Bool = true) -> Bool {
        let options = [
            "AXTrustedCheckOptionPrompt": true
        ] as CFDictionary

        let trusted = AXIsProcessTrustedWithOptions(options)
        if openSettings, !trusted {
            openAccessibilitySettingsThrottled()
        }
        return trusted
    }

    func hasAccessibilityPermission() -> Bool {
        AXIsProcessTrusted()
    }

    func insert(_ text: String, into targetApplication: NSRunningApplication?) async throws -> NSRunningApplication? {
        guard hasAccessibilityPermission() else {
            throw PasteError.accessibilityPermissionMissing
        }

        let pasteboard = NSPasteboard.general
        let snapshot = capture(pasteboard)

        guard let pasteTarget = currentPasteTarget(), focusedTextInputExists(in: pasteTarget) else {
            throw PasteError.focusedTextInputMissing
        }

        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        sendPasteShortcut()

        try? await Task.sleep(nanoseconds: 1_200_000_000)
        restore(snapshot, to: pasteboard)
        return pasteTarget
    }

    private func capture(_ pasteboard: NSPasteboard) -> PasteboardSnapshot {
        let items = pasteboard.pasteboardItems?.map { item in
            item.types.reduce(into: [NSPasteboard.PasteboardType: Data]()) { result, type in
                result[type] = item.data(forType: type)
            }
        } ?? []

        return PasteboardSnapshot(items: items)
    }

    private func restore(_ snapshot: PasteboardSnapshot, to pasteboard: NSPasteboard) {
        pasteboard.clearContents()
        guard !snapshot.items.isEmpty else { return }

        let items = snapshot.items.map { values in
            let item = NSPasteboardItem()
            for (type, data) in values {
                item.setData(data, forType: type)
            }
            return item
        }

        pasteboard.writeObjects(items)
    }

    private func currentPasteTarget() -> NSRunningApplication? {
        guard
            let app = NSWorkspace.shared.frontmostApplication,
            !app.isTerminated,
            app.bundleIdentifier != AppPaths.bundleIdentifier
        else {
            return nil
        }

        return app
    }

    private func focusedTextInputExists(in targetApplication: NSRunningApplication?) -> Bool {
        guard
            let app = targetApplication ?? NSWorkspace.shared.frontmostApplication,
            !app.isTerminated
        else {
            return false
        }

        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        var focusedObject: CFTypeRef?
        let focusedStatus = AXUIElementCopyAttributeValue(
            appElement,
            kAXFocusedUIElementAttribute as CFString,
            &focusedObject
        )

        guard focusedStatus == .success, let focusedObject else {
            return false
        }

        let focusedElement = focusedObject as! AXUIElement
        let role = stringAttribute(kAXRoleAttribute, from: focusedElement)
        let subrole = stringAttribute(kAXSubroleAttribute, from: focusedElement)
        if FocusedTextInputPolicy.isWritable(role: role, subrole: subrole) {
            return true
        }

        var parentObject: CFTypeRef?
        let parentStatus = AXUIElementCopyAttributeValue(
            focusedElement,
            kAXParentAttribute as CFString,
            &parentObject
        )

        guard parentStatus == .success, let parentObject else {
            return false
        }

        let parentElement = parentObject as! AXUIElement
        let parentRole = stringAttribute(kAXRoleAttribute, from: parentElement)
        let parentSubrole = stringAttribute(kAXSubroleAttribute, from: parentElement)
        return FocusedTextInputPolicy.isWritable(role: parentRole, subrole: parentSubrole)
    }

    private func stringAttribute(_ attribute: String, from element: AXUIElement) -> String? {
        var value: CFTypeRef?
        let status = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
        guard status == .success else { return nil }
        return value as? String
    }

    private func sendPasteShortcut() {
        let source = CGEventSource(stateID: .hidSystemState)
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: false)

        keyDown?.flags = .maskCommand
        keyUp?.flags = .maskCommand
        keyDown?.post(tap: .cghidEventTap)
        usleep(30_000)
        keyUp?.post(tap: .cghidEventTap)
    }

    private func openAccessibilitySettingsThrottled() {
        let now = Date()
        if let lastSettingsOpenAt, now.timeIntervalSince(lastSettingsOpenAt) < 8 {
            return
        }
        lastSettingsOpenAt = now

        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else {
            return
        }
        NSWorkspace.shared.open(url)
    }
}
