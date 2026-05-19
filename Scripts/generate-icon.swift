#!/usr/bin/env swift

import AppKit
import Foundation

let outputPath = CommandLine.arguments.dropFirst().first ?? "build/AppIcon.iconset"
let outputURL = URL(fileURLWithPath: outputPath)
try? FileManager.default.removeItem(at: outputURL)
try FileManager.default.createDirectory(at: outputURL, withIntermediateDirectories: true)

let specs: [(String, CGFloat)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]

for (name, size) in specs {
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: Int(size),
        pixelsHigh: Int(size),
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        fatalError("Could not create bitmap for \(name)")
    }

    bitmap.size = NSSize(width: size, height: size)

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    drawIcon(size: size)
    NSGraphicsContext.current?.flushGraphics()
    NSGraphicsContext.restoreGraphicsState()

    guard
        let data = bitmap.representation(using: .png, properties: [:])
    else {
        fatalError("Could not render icon \(name)")
    }

    try data.write(to: outputURL.appendingPathComponent(name), options: .atomic)
}

func drawIcon(size: CGFloat) {
    let rect = NSRect(x: 0, y: 0, width: size, height: size)
    NSColor.clear.setFill()
    rect.fill()

    let bgRect = rect.insetBy(dx: size * 0.08, dy: size * 0.08)
    let bg = NSBezierPath(roundedRect: bgRect, xRadius: size * 0.22, yRadius: size * 0.22)
    let gradient = NSGradient(colors: [
        NSColor(calibratedRed: 0.18, green: 0.19, blue: 0.21, alpha: 1),
        NSColor(calibratedRed: 0.02, green: 0.025, blue: 0.035, alpha: 1)
    ])
    gradient?.draw(in: bg, angle: 235)

    NSColor(calibratedWhite: 1, alpha: 0.18).setStroke()
    bg.lineWidth = max(1, size * 0.01)
    bg.stroke()

    // Diagonal glossy facet, matching the selected black glass reference.
    let facet = NSBezierPath()
    facet.move(to: NSPoint(x: bgRect.maxX - size * 0.02, y: bgRect.maxY - size * 0.02))
    facet.line(to: NSPoint(x: bgRect.maxX - size * 0.02, y: bgRect.minY + size * 0.12))
    facet.line(to: NSPoint(x: bgRect.minX + size * 0.40, y: bgRect.minY + size * 0.12))
    facet.close()
    NSColor.black.withAlphaComponent(0.28).setFill()
    facet.fill()

    let highlight = NSBezierPath()
    highlight.move(to: NSPoint(x: bgRect.minX + size * 0.13, y: bgRect.maxY - size * 0.03))
    highlight.curve(
        to: NSPoint(x: bgRect.maxX - size * 0.04, y: bgRect.maxY - size * 0.12),
        controlPoint1: NSPoint(x: bgRect.minX + size * 0.40, y: bgRect.maxY + size * 0.06),
        controlPoint2: NSPoint(x: bgRect.maxX - size * 0.13, y: bgRect.maxY + size * 0.02)
    )
    NSColor.white.withAlphaComponent(0.12).setStroke()
    highlight.lineWidth = max(1, size * 0.018)
    highlight.stroke()

    let laptopColor = NSColor(calibratedWhite: 0.90, alpha: 0.86)
    let baseShadow = NSBezierPath(roundedRect: NSRect(x: size * 0.20, y: size * 0.165, width: size * 0.60, height: size * 0.060), xRadius: size * 0.030, yRadius: size * 0.030)
    NSColor.black.withAlphaComponent(0.36).setFill()
    baseShadow.fill()

    let base = NSBezierPath(roundedRect: NSRect(x: size * 0.18, y: size * 0.185, width: size * 0.64, height: size * 0.060), xRadius: size * 0.030, yRadius: size * 0.030)
    laptopColor.setFill()
    base.fill()

    let screenLine = NSBezierPath()
    screenLine.move(to: NSPoint(x: size * 0.255, y: size * 0.255))
    screenLine.line(to: NSPoint(x: size * 0.745, y: size * 0.255))
    NSColor.white.withAlphaComponent(0.16).setStroke()
    screenLine.lineWidth = max(1, size * 0.012)
    screenLine.stroke()

    let white = NSColor(calibratedWhite: 0.94, alpha: 1)
    let ringRect = NSRect(x: size * 0.245, y: size * 0.255, width: size * 0.51, height: size * 0.51)
    let ring = NSBezierPath(ovalIn: ringRect)
    white.withAlphaComponent(0.92).setStroke()
    ring.lineWidth = max(1.3, size * 0.022)
    ring.stroke()

    let micRect = NSRect(x: size * 0.415, y: size * 0.455, width: size * 0.17, height: size * 0.205)
    let capsule = NSBezierPath(roundedRect: micRect, xRadius: size * 0.085, yRadius: size * 0.085)
    white.setFill()
    capsule.fill()

    for offset in [-0.040, 0.0, 0.040] {
        let line = NSBezierPath()
        line.move(to: NSPoint(x: size * 0.455, y: size * (0.525 + offset)))
        line.line(to: NSPoint(x: size * 0.545, y: size * (0.525 + offset)))
        NSColor.black.withAlphaComponent(0.42).setStroke()
        line.lineWidth = max(1, size * 0.012)
        line.stroke()
    }

    let arc = NSBezierPath()
    arc.appendArc(
        withCenter: NSPoint(x: size * 0.5, y: size * 0.415),
        radius: size * 0.155,
        startAngle: 205,
        endAngle: 335,
        clockwise: false
    )
    white.setStroke()
    arc.lineWidth = max(1.6, size * 0.030)
    arc.stroke()

    let stem = NSBezierPath()
    stem.move(to: NSPoint(x: size * 0.5, y: size * 0.285))
    stem.line(to: NSPoint(x: size * 0.5, y: size * 0.370))
    stem.lineWidth = max(1.6, size * 0.030)
    stem.stroke()

    let micBase = NSBezierPath()
    micBase.move(to: NSPoint(x: size * 0.42, y: size * 0.285))
    micBase.line(to: NSPoint(x: size * 0.58, y: size * 0.285))
    micBase.lineWidth = max(1.6, size * 0.030)
    micBase.stroke()
}
