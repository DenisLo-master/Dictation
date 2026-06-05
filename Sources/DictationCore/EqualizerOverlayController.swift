import AppKit

@MainActor
final class EqualizerOverlayController {
    private let size = NSSize(width: 150, height: 50)
    private let panel: NSPanel
    private let equalizerView: EqualizerView
    private var pulseTimer: Timer?

    init() {
        equalizerView = EqualizerView(frame: NSRect(origin: .zero, size: size))
        panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        panel.contentView = equalizerView
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        configurePanelForOverlay()
    }

    func showPreparing() {
        stopPulse()
        configurePanelForOverlay()
        positionBottomRight()
        equalizerView.mode = .preparing
        equalizerView.resetLevels()
        equalizerView.setLevel(0)
        panel.orderFrontRegardless()
    }

    func showRecording() {
        stopPulse()
        configurePanelForOverlay()
        positionBottomRight()
        equalizerView.mode = .recording
        equalizerView.resetLevels()
        panel.orderFrontRegardless()
    }

    func hide() {
        stopPulse()
        panel.orderOut(nil)
    }

    func update(level: CGFloat) {
        equalizerView.setLevel(level)
    }

    func setTranscribing() {
        stopPulse()
        equalizerView.mode = .transcribing
        if !panel.isVisible {
            configurePanelForOverlay()
            positionBottomRight()
            panel.orderFrontRegardless()
        }
        startPulse()
    }

    func flashSuccessAndHide() {
        stopPulse()
        equalizerView.mode = .success
        equalizerView.setLevel(0.9)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { [weak self] in
            self?.hide()
        }
    }

    func flashFailureAndHide() {
        stopPulse()
        equalizerView.mode = .failure
        equalizerView.setLevel(0.55)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
            self?.hide()
        }
    }

    private func configurePanelForOverlay() {
        panel.level = .screenSaver
        panel.collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .stationary,
            .transient,
            .ignoresCycle
        ]
    }

    private func positionBottomRight() {
        let screen = screenForCurrentPointer() ?? NSScreen.main ?? NSScreen.screens.first
        let frame = screen?.visibleFrame ?? .zero
        let origin = NSPoint(
            x: frame.maxX - size.width - 24,
            y: frame.minY + 24
        )
        panel.setFrame(NSRect(origin: origin, size: size), display: true)
    }

    private func screenForCurrentPointer() -> NSScreen? {
        let mouseLocation = NSEvent.mouseLocation
        return NSScreen.screens.first { screen in
            screen.frame.contains(mouseLocation)
        }
    }

    private func startPulse() {
        pulseTimer?.invalidate()
        pulseTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 24.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.equalizerView.pulse()
            }
        }
    }

    private func stopPulse() {
        pulseTimer?.invalidate()
        pulseTimer = nil
    }
}

@MainActor
private final class EqualizerView: NSView {
    enum Mode {
        case preparing
        case recording
        case transcribing
        case success
        case failure
    }

    var mode: Mode = .recording {
        didSet { needsDisplay = true }
    }

    private var levels: [CGFloat] = Array(repeating: 0.2, count: 16)
    private var levelHistory = VoiceLevelHistory(columnCount: 16)
    private var phase: CGFloat = 0

    override var isFlipped: Bool { false }

    func resetLevels() {
        levelHistory.reset()
        levels = levelHistory.levels
        phase = 0
        needsDisplay = true
    }

    func setLevel(_ level: CGFloat) {
        let clamped = max(0, min(1, level))
        if mode == .recording {
            levels = levelHistory.push(clamped)
        } else {
            levels = Array(repeating: max(0.02, clamped), count: levels.count)
        }

        needsDisplay = true
    }

    func pulse() {
        phase += 0.22
        levels = levels.indices.map { index in
            0.18 + 0.75 * abs(sin(phase + CGFloat(index) * 0.38))
        }
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let rect = bounds.insetBy(dx: 0.5, dy: 0.5)
        let background = NSBezierPath(roundedRect: rect, xRadius: 18, yRadius: 18)
        NSColor.black.withAlphaComponent(0.64).setFill()
        background.fill()

        NSColor.white.withAlphaComponent(0.14).setStroke()
        background.lineWidth = 1
        background.stroke()

        drawMicrophone(in: NSRect(x: 16, y: 9, width: 28, height: 32))
        if mode == .preparing {
            drawPreparingDots(in: NSRect(x: 55, y: 22, width: 62, height: 6))
        } else if mode == .transcribing {
            drawSpinner(in: NSRect(x: 78, y: 12, width: 26, height: 26))
        } else {
            drawCells(in: NSRect(x: 49, y: 10, width: 87, height: 30))
        }
    }

    private func drawMicrophone(in rect: NSRect) {
        BadgeMicrophoneIcon.draw(in: rect, color: activeColor(), cutoutColor: .black)
    }

    private func drawCells(in rect: NSRect) {
        let color = activeColor()
        let cell: CGFloat = 4
        let gap: CGFloat = 1.5
        let rows = 6

        for (column, level) in levels.enumerated() {
            let scaledLevel = max(0, min(CGFloat(rows), level * CGFloat(rows)))
            let fullRows = Int(floor(scaledLevel))
            let partialRow = min(1, max(0, scaledLevel - CGFloat(fullRows)))
            let x = rect.minX + CGFloat(column) * (cell + gap)

            for row in 0..<rows {
                let y = rect.minY + CGFloat(row) * (cell + gap) + 1
                let path = NSBezierPath(roundedRect: NSRect(x: x, y: y, width: cell, height: cell), xRadius: 1.1, yRadius: 1.1)
                if row < fullRows {
                    let alpha = 0.48 + 0.075 * CGFloat(row + 1)
                    color.withAlphaComponent(min(0.98, alpha)).setFill()
                } else if row == fullRows, partialRow > 0.05 {
                    let alpha = 0.16 + 0.56 * partialRow + 0.04 * CGFloat(row)
                    color.withAlphaComponent(min(0.92, alpha)).setFill()
                } else {
                    color.withAlphaComponent(0.08).setFill()
                }
                path.fill()
            }
        }
    }

    private func activeColor() -> NSColor {
        switch mode {
        case .preparing:
            return .tertiaryLabelColor
        case .recording:
            return NSColor(calibratedRed: 0.20, green: 0.92, blue: 0.86, alpha: 1)
        case .transcribing:
            return .systemIndigo
        case .success:
            return .systemGreen
        case .failure:
            return .systemRed
        }
    }

    private func drawPreparingDots(in rect: NSRect) {
        let color = NSColor.tertiaryLabelColor
        for index in 0..<3 {
            let x = rect.minX + CGFloat(index) * 14
            let path = NSBezierPath(ovalIn: NSRect(x: x, y: rect.minY, width: 6, height: 6))
            color.withAlphaComponent(0.5 + CGFloat(index) * 0.14).setFill()
            path.fill()
        }
    }

    private func drawSpinner(in rect: NSRect) {
        let color = activeColor()
        let segments = 10
        let center = NSPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) * 0.39
        let segmentSize = NSSize(width: 4.0, height: 4.0)
        let activeIndex = Int(phase * 10).positiveModulo(segments)

        for index in 0..<segments {
            let angle = (CGFloat(index) / CGFloat(segments)) * .pi * 2 - .pi / 2
            let x = center.x + cos(angle) * radius - segmentSize.width / 2
            let y = center.y + sin(angle) * radius - segmentSize.height / 2
            let distance = (index - activeIndex + segments) % segments
            let alpha = max(0.16, 0.98 - CGFloat(distance) * 0.095)
            let dot = NSBezierPath(roundedRect: NSRect(origin: NSPoint(x: x, y: y), size: segmentSize), xRadius: 1.5, yRadius: 1.5)
            color.withAlphaComponent(alpha).setFill()
            dot.fill()
        }
    }
}

private extension Int {
    func positiveModulo(_ divisor: Int) -> Int {
        let result = self % divisor
        return result >= 0 ? result : result + divisor
    }
}
