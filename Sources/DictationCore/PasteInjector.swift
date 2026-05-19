import AppKit
import ApplicationServices
import Carbon

@MainActor
final class PasteInjector {
    enum PasteError: LocalizedError {
        case accessibilityPermissionMissing

        var errorDescription: String? {
            switch self {
            case .accessibilityPermissionMissing:
                "Accessibility permission is required to paste into another app."
            }
        }
    }

    private struct PasteboardSnapshot {
        let items: [[NSPasteboard.PasteboardType: Data]]
    }

    func requestAccessibilityPermission() -> Bool {
        let options = [
            "AXTrustedCheckOptionPrompt": true
        ] as CFDictionary

        return AXIsProcessTrustedWithOptions(options)
    }

    func hasAccessibilityPermission() -> Bool {
        AXIsProcessTrusted()
    }

    func insert(_ text: String, into targetApplication: NSRunningApplication?) async throws {
        guard hasAccessibilityPermission() else {
            throw PasteError.accessibilityPermissionMissing
        }

        let pasteboard = NSPasteboard.general
        let snapshot = capture(pasteboard)

        if let targetApplication, !targetApplication.isTerminated {
            targetApplication.activate(options: [.activateAllWindows])
            try? await Task.sleep(nanoseconds: 180_000_000)
        }

        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        sendPasteShortcut()

        try? await Task.sleep(nanoseconds: 1_200_000_000)
        restore(snapshot, to: pasteboard)
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
}
