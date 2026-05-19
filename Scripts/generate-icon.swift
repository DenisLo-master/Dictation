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
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    drawIcon(size: size)
    image.unlockFocus()

    guard
        let tiff = image.tiffRepresentation,
        let bitmap = NSBitmapImageRep(data: tiff),
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

    let bg = NSBezierPath(roundedRect: rect.insetBy(dx: size * 0.08, dy: size * 0.08), xRadius: size * 0.22, yRadius: size * 0.22)
    let gradient = NSGradient(colors: [
        NSColor(calibratedRed: 0.07, green: 0.74, blue: 0.78, alpha: 1),
        NSColor(calibratedRed: 0.12, green: 0.24, blue: 0.78, alpha: 1)
    ])
    gradient?.draw(in: bg, angle: 225)

    NSColor.white.withAlphaComponent(0.2).setStroke()
    bg.lineWidth = max(1, size * 0.012)
    bg.stroke()

    let laptop = NSRect(x: size * 0.18, y: size * 0.2, width: size * 0.64, height: size * 0.4)
    let screen = NSBezierPath(roundedRect: laptop, xRadius: size * 0.045, yRadius: size * 0.045)
    NSColor.white.withAlphaComponent(0.92).setStroke()
    screen.lineWidth = size * 0.055
    screen.stroke()

    let base = NSBezierPath(roundedRect: NSRect(x: size * 0.14, y: size * 0.14, width: size * 0.72, height: size * 0.075), xRadius: size * 0.035, yRadius: size * 0.035)
    NSColor.white.withAlphaComponent(0.92).setFill()
    base.fill()

    let micRect = NSRect(x: size * 0.41, y: size * 0.38, width: size * 0.18, height: size * 0.33)
    let capsule = NSBezierPath(roundedRect: micRect, xRadius: size * 0.09, yRadius: size * 0.09)
    NSColor.white.setFill()
    capsule.fill()

    let arc = NSBezierPath()
    arc.appendArc(
        withCenter: NSPoint(x: size * 0.5, y: size * 0.43),
        radius: size * 0.17,
        startAngle: 205,
        endAngle: 335,
        clockwise: false
    )
    arc.lineWidth = size * 0.045
    arc.stroke()

    let stem = NSBezierPath()
    stem.move(to: NSPoint(x: size * 0.5, y: size * 0.24))
    stem.line(to: NSPoint(x: size * 0.5, y: size * 0.34))
    stem.lineWidth = size * 0.045
    stem.stroke()
}
