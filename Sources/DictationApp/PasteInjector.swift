import AppKit
import ApplicationServices
import Carbon

@MainActor
final class PasteInjector {
    private struct PasteboardSnapshot {
        let items: [[NSPasteboard.PasteboardType: Data]]
    }

    func requestAccessibilityPermission() -> Bool {
        let options = [
            "AXTrustedCheckOptionPrompt": true
        ] as CFDictionary

        return AXIsProcessTrustedWithOptions(options)
    }

    func insert(_ text: String) {
        let pasteboard = NSPasteboard.general
        let snapshot = capture(pasteboard)

        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        sendPasteShortcut()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            self.restore(snapshot, to: pasteboard)
        }
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
        keyUp?.post(tap: .cghidEventTap)
    }
}
