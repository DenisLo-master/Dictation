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
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
    }

    func showPreparing() {
        stopPulse()
        positionBottomRight()
        equalizerView.mode = .preparing
        equalizerView.setLevel(0)
        panel.orderFrontRegardless()
    }

    func showRecording() {
        stopPulse()
        positionBottomRight()
        equalizerView.mode = .recording
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
        equalizerView.mode = .transcribing
        if !panel.isVisible {
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

    private func positionBottomRight() {
        let frame = NSScreen.main?.visibleFrame ?? NSScreen.screens.first?.visibleFrame ?? .zero
        let origin = NSPoint(
            x: frame.maxX - size.width - 24,
            y: frame.minY + 24
        )
        panel.setFrame(NSRect(origin: origin, size: size), display: true)
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
    private var phase: CGFloat = 0

    override var isFlipped: Bool { false }

    func setLevel(_ level: CGFloat) {
        let clamped = max(0.02, min(1.0, pow(level, 0.62)))
        levels = levels.enumerated().map { index, current in
            let wave = 0.64 + 0.36 * sin(CGFloat(index) * 0.82 + phase)
            let target = max(0.03, min(1.0, clamped * wave + CGFloat.random(in: -0.10...0.16)))
            return current * 0.48 + target * 0.52
        }
        phase += 0.26
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

        drawMicrophone(in: NSRect(x: 17, y: 13, width: 22, height: 24))
        if mode == .preparing {
            drawPreparingDots(in: NSRect(x: 55, y: 22, width: 62, height: 6))
        } else {
            drawCells(in: NSRect(x: 49, y: 10, width: 87, height: 30))
        }
    }

    private func drawMicrophone(in rect: NSRect) {
        let color = activeColor()
        color.withAlphaComponent(0.95).setStroke()
        color.withAlphaComponent(0.95).setFill()

        let capsule = NSBezierPath(roundedRect: NSRect(x: rect.midX - 4, y: rect.minY + 8, width: 8, height: 14), xRadius: 4, yRadius: 4)
        capsule.fill()

        let arc = NSBezierPath()
        arc.appendArc(
            withCenter: NSPoint(x: rect.midX, y: rect.minY + 11),
            radius: 8,
            startAngle: 205,
            endAngle: 335,
            clockwise: false
        )
        arc.lineWidth = 2
        arc.stroke()

        let stem = NSBezierPath()
        stem.move(to: NSPoint(x: rect.midX, y: rect.minY + 3))
        stem.line(to: NSPoint(x: rect.midX, y: rect.minY + 8))
        stem.lineWidth = 2
        stem.stroke()

        let base = NSBezierPath()
        base.move(to: NSPoint(x: rect.midX - 6, y: rect.minY + 3))
        base.line(to: NSPoint(x: rect.midX + 6, y: rect.minY + 3))
        base.lineWidth = 2
        base.stroke()
    }

    private func drawCells(in rect: NSRect) {
        let color = activeColor()
        let cell: CGFloat = 4
        let gap: CGFloat = 2
        let rows = 5

        for (column, level) in levels.enumerated() {
            let activeRows = max(1, min(rows, Int(ceil(level * CGFloat(rows)))))
            let x = rect.minX + CGFloat(column) * (cell + gap)

            for row in 0..<activeRows {
                let y = rect.minY + CGFloat(row) * (cell + gap) + 1
                let alpha = 0.36 + 0.12 * CGFloat(row + 1)
                let path = NSBezierPath(roundedRect: NSRect(x: x, y: y, width: cell, height: cell), xRadius: 1.1, yRadius: 1.1)
                color.withAlphaComponent(min(0.95, alpha)).setFill()
                path.fill()
            }
        }
    }

    private func activeColor() -> NSColor {
        switch mode {
        case .preparing:
            return .tertiaryLabelColor
        case .recording:
            return .systemTeal
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
}
