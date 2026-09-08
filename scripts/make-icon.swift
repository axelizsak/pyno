#!/usr/bin/env swift
// Generates Resources/AppIcon.icns: white rounded square with an orange waveform.
// Run automatically by build-app.sh when the icon is missing.
import AppKit
import Foundation

let arguments = CommandLine.arguments
let outputPath = arguments.count > 1 ? arguments[1] : "Resources/AppIcon.icns"
let workDirectory = URL(fileURLWithPath: NSTemporaryDirectory())
    .appendingPathComponent("pyno-icon-\(UUID().uuidString)")
let iconset = workDirectory.appendingPathComponent("AppIcon.iconset")
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

/// Relative bar heights. Fixed pattern (not random) so every build produces the same icon.
let bars: [CGFloat] = [0.22, 0.44, 0.72, 0.95, 0.62, 0.86, 0.34, 0.58, 0.90, 0.48, 0.26]

let colorSpace = CGColorSpaceCreateDeviceRGB()
func color(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(colorSpace: colorSpace, components: [red, green, blue, alpha])!
}

func render(size: Int) -> Data? {
    let side = CGFloat(size)
    let image = NSImage(size: NSSize(width: side, height: side))
    image.lockFocus()
    guard let context = NSGraphicsContext.current?.cgContext else {
        image.unlockFocus()
        return nil
    }
    context.setShouldAntialias(true)

    // macOS-style rounded square, with a little padding inside the canvas.
    let inset = side * 0.055
    let rect = CGRect(x: inset, y: inset, width: side - inset * 2, height: side - inset * 2)
    let squircle = CGPath(
        roundedRect: rect,
        cornerWidth: rect.width * 0.2237,
        cornerHeight: rect.height * 0.2237,
        transform: nil
    )

    context.saveGState()
    context.addPath(squircle)
    context.clip()
    context.setFillColor(color(1, 1, 1))
    context.fill(rect)

    // Orange waveform, centered. Deliberately short so the white plate stays dominant.
    let barWidth = rect.width * 0.045
    let spacing = rect.width * 0.0295
    let totalWidth = CGFloat(bars.count) * barWidth + CGFloat(bars.count - 1) * spacing
    var x = rect.midX - totalWidth / 2
    let maxHeight = rect.height * 0.42
    let waveform = CGMutablePath()
    for bar in bars {
        let height = max(barWidth, maxHeight * bar)
        let barRect = CGRect(x: x, y: rect.midY - height / 2, width: barWidth, height: height)
        waveform.addPath(
            CGPath(roundedRect: barRect, cornerWidth: barWidth / 2, cornerHeight: barWidth / 2, transform: nil))
        x += barWidth + spacing
    }
    context.addPath(waveform)
    context.clip()
    let orange = CGGradient(
        colorsSpace: colorSpace,
        colors: [color(1.0, 0.56, 0.20), color(0.94, 0.36, 0.02)] as CFArray,
        locations: [0, 1]
    )!
    context.drawLinearGradient(
        orange,
        start: CGPoint(x: rect.midX, y: rect.midY + maxHeight / 2),
        end: CGPoint(x: rect.midX, y: rect.midY - maxHeight / 2),
        options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
    )
    context.restoreGState()

    // Hairline edge so the white plate stays visible on a light background.
    context.saveGState()
    context.addPath(squircle)
    context.setStrokeColor(color(0, 0, 0, 0.10))
    context.setLineWidth(max(1, side * 0.004))
    context.strokePath()
    context.restoreGState()

    image.unlockFocus()

    guard let tiff = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiff) else { return nil }
    bitmap.size = NSSize(width: side, height: side)
    return bitmap.representation(using: .png, properties: [:])
}

let variants: [(name: String, size: Int)] = [
    ("icon_16x16", 16), ("icon_16x16@2x", 32),
    ("icon_32x32", 32), ("icon_32x32@2x", 64),
    ("icon_128x128", 128), ("icon_128x128@2x", 256),
    ("icon_256x256", 256), ("icon_256x256@2x", 512),
    ("icon_512x512", 512), ("icon_512x512@2x", 1024),
]

for variant in variants {
    guard let data = render(size: variant.size) else {
        FileHandle.standardError.write(Data("Failed to render \(variant.name)\n".utf8))
        exit(1)
    }
    try data.write(to: iconset.appendingPathComponent("\(variant.name).png"))
}

let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", iconset.path, "-o", outputPath]
try process.run()
process.waitUntilExit()
try? FileManager.default.removeItem(at: workDirectory)
exit(process.terminationStatus)
