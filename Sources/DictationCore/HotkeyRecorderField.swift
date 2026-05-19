import AppKit

@MainActor
final class HotkeyRecorderField: NSControl {
    var onCapture: ((DictationHotkey) -> Void)?
    var onInvalidCapture: ((String) -> Void)?
    var onRecordingStateChange: ((Bool) -> Void)?

    var hotkey: DictationHotkey = .defaultHotkey {
        didSet {
            isRecording = false
            needsDisplay = true
        }
    }

    private var isRecording = false {
        didSet {
            if oldValue != isRecording {
                onRecordingStateChange?(isRecording)
            }
            needsDisplay = true
        }
    }

    override var acceptsFirstResponder: Bool { true }
    override var intrinsicContentSize: NSSize { NSSize(width: 150, height: 30) }

    override func mouseDown(with event: NSEvent) {
        isRecording = true
        window?.makeFirstResponder(self)
    }

    override func keyDown(with event: NSEvent) {
        capture(event)
    }

    override func keyUp(with event: NSEvent) {}

    override func flagsChanged(with event: NSEvent) {
        capture(event)
    }

    override func resignFirstResponder() -> Bool {
        isRecording = false
        return super.resignFirstResponder()
    }

    override func draw(_ dirtyRect: NSRect) {
        let rect = bounds.insetBy(dx: 0.5, dy: 0.5)
        let path = NSBezierPath(roundedRect: rect, xRadius: 7, yRadius: 7)

        (isRecording ? NSColor.controlAccentColor.withAlphaComponent(0.18) : NSColor.controlBackgroundColor).setFill()
        path.fill()

        (isRecording ? NSColor.controlAccentColor : NSColor.separatorColor).setStroke()
        path.lineWidth = isRecording ? 1.5 : 1
        path.stroke()

        let text = isRecording ? "Нажмите клавишу..." : hotkey.displayName
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12, weight: .medium),
            .foregroundColor: isRecording ? NSColor.controlAccentColor : NSColor.labelColor
        ]
        let attributed = NSAttributedString(string: text, attributes: attributes)
        let textRect = NSRect(
            x: rect.minX + 10,
            y: rect.midY - attributed.size().height / 2,
            width: rect.width - 20,
            height: attributed.size().height
        )
        attributed.draw(in: textRect)
    }

    private func capture(_ event: NSEvent) {
        guard isRecording else {
            return
        }

        if let captured = DictationHotkey.capture(from: event) {
            hotkey = captured
            window?.makeFirstResponder(nil)
            onCapture?(captured)
        } else if event.type == .keyDown {
            onInvalidCapture?(DictationHotkey.invalidReason(for: event))
        }
    }
}
