import AppKit

enum BadgeMicrophoneIcon {
    static func draw(in rect: NSRect, color: NSColor, cutoutColor _: NSColor = .black) {
        let iconColor = color.withAlphaComponent(0.96)
        iconColor.setFill()
        iconColor.setStroke()

        let body = NSBezierPath(
            roundedRect: NSRect(
                x: rect.midX - rect.width * 0.17,
                y: rect.minY + rect.height * 0.38,
                width: rect.width * 0.34,
                height: rect.height * 0.52
            ),
            xRadius: rect.width * 0.17,
            yRadius: rect.width * 0.17
        )
        body.fill()

        let arc = NSBezierPath()
        arc.move(to: NSPoint(
            x: rect.minX + rect.width * 0.20,
            y: rect.minY + rect.height * 0.56
        ))
        arc.curve(
            to: NSPoint(x: rect.midX, y: rect.minY + rect.height * 0.23),
            controlPoint1: NSPoint(x: rect.minX + rect.width * 0.20, y: rect.minY + rect.height * 0.34),
            controlPoint2: NSPoint(x: rect.minX + rect.width * 0.32, y: rect.minY + rect.height * 0.23)
        )
        arc.curve(
            to: NSPoint(x: rect.maxX - rect.width * 0.20, y: rect.minY + rect.height * 0.56),
            controlPoint1: NSPoint(x: rect.maxX - rect.width * 0.32, y: rect.minY + rect.height * 0.23),
            controlPoint2: NSPoint(x: rect.maxX - rect.width * 0.20, y: rect.minY + rect.height * 0.34)
        )
        arc.lineCapStyle = .round
        arc.lineJoinStyle = .round
        arc.lineWidth = rect.width * 0.13
        arc.stroke()

        let stem = NSBezierPath()
        stem.move(to: NSPoint(x: rect.midX, y: rect.minY + rect.height * 0.20))
        stem.line(to: NSPoint(x: rect.midX, y: rect.minY + rect.height * 0.07))
        stem.lineCapStyle = .round
        stem.lineWidth = rect.width * 0.11
        stem.stroke()

        let base = NSBezierPath(
            roundedRect: NSRect(
                x: rect.midX - rect.width * 0.23,
                y: rect.minY + rect.height * 0.05,
                width: rect.width * 0.46,
                height: rect.height * 0.10
            ),
            xRadius: rect.height * 0.05,
            yRadius: rect.height * 0.05
        )
        base.fill()
    }
}
