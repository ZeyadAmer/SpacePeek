#!/usr/bin/env swift
import AppKit
import Foundation

let outputDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "Resources"
let iconsetDir = "\(outputDir)/AppIcon.iconset"
try? FileManager.default.createDirectory(atPath: iconsetDir, withIntermediateDirectories: true)

func render(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()

    let rect = NSRect(x: 0, y: 0, width: size, height: size)
    let radius = size * 0.22
    let bgPath = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
    let top = NSColor(red: 0.18, green: 0.26, blue: 0.50, alpha: 1.0)
    let bottom = NSColor(red: 0.06, green: 0.09, blue: 0.18, alpha: 1.0)
    let gradient = NSGradient(starting: top, ending: bottom)!
    gradient.draw(in: bgPath, angle: -90)

    let stripPadding = size * 0.10
    let stripWidth = size - 2 * stripPadding
    let stripHeight = size * 0.20
    let stripY = size * 0.58
    let tileCount = 5
    let tileGap = size * 0.028
    let tileWidth = (stripWidth - CGFloat(tileCount - 1) * tileGap) / CGFloat(tileCount)

    for i in 0..<tileCount {
        let x = stripPadding + CGFloat(i) * (tileWidth + tileGap)
        let tileRect = NSRect(x: x, y: stripY, width: tileWidth, height: stripHeight)
        let tilePath = NSBezierPath(roundedRect: tileRect, xRadius: size * 0.028, yRadius: size * 0.028)
        if i == 2 {
            NSColor.white.setFill()
        } else {
            NSColor.white.withAlphaComponent(0.78).setFill()
        }
        tilePath.fill()
        if i == 2 {
            NSColor(red: 0.35, green: 0.62, blue: 1.0, alpha: 1.0).setStroke()
            tilePath.lineWidth = size * 0.012
            tilePath.stroke()
        }
    }

    let labelY = stripY - size * 0.08
    let labelHeight = size * 0.04
    for i in 0..<tileCount {
        let centerX = stripPadding + CGFloat(i) * (tileWidth + tileGap) + tileWidth / 2
        let w = tileWidth * (i == 2 ? 0.85 : 0.65)
        let labelRect = NSRect(x: centerX - w / 2, y: labelY, width: w, height: labelHeight)
        let labelPath = NSBezierPath(roundedRect: labelRect, xRadius: labelHeight / 2, yRadius: labelHeight / 2)
        let alpha: CGFloat = i == 2 ? 1.0 : 0.78
        NSColor.white.withAlphaComponent(alpha).setFill()
        labelPath.fill()
    }

    image.unlockFocus()
    return image
}

func savePNG(image: NSImage, size: CGFloat, path: String) {
    let rep = NSBitmapImageRep(
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
    )!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    image.draw(in: NSRect(x: 0, y: 0, width: size, height: size))
    NSGraphicsContext.restoreGraphicsState()

    guard let data = rep.representation(using: .png, properties: [:]) else {
        FileHandle.standardError.write(Data("Failed to encode PNG\n".utf8))
        exit(1)
    }
    try! data.write(to: URL(fileURLWithPath: path))
}

let sizes: [(CGFloat, String)] = [
    (16, "icon_16x16.png"),
    (32, "icon_16x16@2x.png"),
    (32, "icon_32x32.png"),
    (64, "icon_32x32@2x.png"),
    (128, "icon_128x128.png"),
    (256, "icon_128x128@2x.png"),
    (256, "icon_256x256.png"),
    (512, "icon_256x256@2x.png"),
    (512, "icon_512x512.png"),
    (1024, "icon_512x512@2x.png"),
]

for (size, name) in sizes {
    let img = render(size: size)
    savePNG(image: img, size: size, path: "\(iconsetDir)/\(name)")
    print("wrote \(iconsetDir)/\(name)")
}

print("Running iconutil...")
let task = Process()
task.launchPath = "/usr/bin/iconutil"
task.arguments = ["--convert", "icns", iconsetDir, "--output", "\(outputDir)/AppIcon.icns"]
try! task.run()
task.waitUntilExit()
print("Done: \(outputDir)/AppIcon.icns")
