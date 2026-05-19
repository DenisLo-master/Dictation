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

    let bgRect = rect.insetBy(dx: size * 0.075, dy: size * 0.075)
    let bg = NSBezierPath(roundedRect: bgRect, xRadius: size * 0.235, yRadius: size * 0.235)
    let gradient = NSGradient(colors: [
        NSColor(calibratedRed: 0.08, green: 0.10, blue: 0.14, alpha: 1),
        NSColor(calibratedRed: 0.01, green: 0.02, blue: 0.04, alpha: 1)
    ])
    gradient?.draw(in: bg, angle: 230)

    NSColor(calibratedWhite: 1, alpha: 0.16).setStroke()
    bg.lineWidth = max(1, size * 0.012)
    bg.stroke()

    let shine = NSBezierPath(roundedRect: bgRect.insetBy(dx: size * 0.05, dy: size * 0.055), xRadius: size * 0.18, yRadius: size * 0.18)
    NSColor.white.withAlphaComponent(0.055).setFill()
    shine.fill()

    let micColor = NSColor(calibratedRed: 0.36, green: 0.96, blue: 0.94, alpha: 1)
    let laptopColor = NSColor(calibratedWhite: 0.94, alpha: 0.88)

    let laptopScreen = NSRect(x: size * 0.27, y: size * 0.18, width: size * 0.46, height: size * 0.26)
    let screen = NSBezierPath(roundedRect: laptopScreen, xRadius: size * 0.045, yRadius: size * 0.045)
    laptopColor.withAlphaComponent(0.30).setFill()
    screen.fill()
    laptopColor.withAlphaComponent(0.62).setStroke()
    screen.lineWidth = max(1.2, size * 0.025)
    screen.stroke()

    let base = NSBezierPath(roundedRect: NSRect(x: size * 0.2, y: size * 0.12, width: size * 0.6, height: size * 0.075), xRadius: size * 0.036, yRadius: size * 0.036)
    laptopColor.setFill()
    base.fill()

    let micRect = NSRect(x: size * 0.39, y: size * 0.42, width: size * 0.22, height: size * 0.33)
    let capsule = NSBezierPath(roundedRect: micRect, xRadius: size * 0.11, yRadius: size * 0.11)
    micColor.setFill()
    capsule.fill()

    NSColor.black.withAlphaComponent(0.22).setFill()
    NSBezierPath(roundedRect: micRect.insetBy(dx: size * 0.045, dy: size * 0.055), xRadius: size * 0.04, yRadius: size * 0.04).fill()

    let arc = NSBezierPath()
    arc.appendArc(
        withCenter: NSPoint(x: size * 0.5, y: size * 0.43),
        radius: size * 0.19,
        startAngle: 205,
        endAngle: 335,
        clockwise: false
    )
    micColor.setStroke()
    arc.lineWidth = size * 0.048
    arc.stroke()

    let stem = NSBezierPath()
    stem.move(to: NSPoint(x: size * 0.5, y: size * 0.28))
    stem.line(to: NSPoint(x: size * 0.5, y: size * 0.38))
    stem.lineWidth = size * 0.048
    stem.stroke()

    for index in 0..<4 {
        let height = size * CGFloat([0.10, 0.16, 0.13, 0.2][index])
        let x = size * (0.66 + CGFloat(index) * 0.055)
        let y = size * 0.49
        let cell = NSBezierPath(roundedRect: NSRect(x: x, y: y, width: size * 0.028, height: height), xRadius: size * 0.012, yRadius: size * 0.012)
        micColor.withAlphaComponent(0.72).setFill()
        cell.fill()
    }
}
