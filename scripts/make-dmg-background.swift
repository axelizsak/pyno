#!/usr/bin/env swift
// Draws the backdrop of the disk image window: a warm plate, an arrow from where
// Pyno sits to where Applications sits, and one line saying what to do.
// Writes a 1x and a 2x PNG; make-dmg.sh folds them into one Retina TIFF.
//
//   swift scripts/make-dmg-background.swift <out.png> <out@2x.png>
//
// The icon positions here must match the ones make-dmg.sh hands to dmgbuild.
import AppKit
import Foundation

// Taller than the visible area on purpose: Finder counts the title bar in the window
// height, so the bottom strip hides under it. Nothing is drawn there.
let width: CGFloat = 660
let height: CGFloat = 440
let appCenter = CGPoint(x: 180, y: 190)
let applicationsCenter = CGPoint(x: 480, y: 190)

let arguments = CommandLine.arguments
guard arguments.count == 3 else {
    FileHandle.standardError.write(Data("usage: make-dmg-background.swift <out.png> <out@2x.png>\n".utf8))
    exit(2)
}

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("make-dmg-background: \(message)\n".utf8))
    exit(1)
}

func rgb(_ hex: UInt32, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(
        srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
        green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255,
        alpha: alpha
    )
}

func render(scale: CGFloat, to path: String) throws {
    // Opaque pixels (alpha skipped): Finder has a history of ignoring window pictures
    // that carry an alpha channel.
    guard let cg = CGContext(
        data: nil,
        width: Int(width * scale), height: Int(height * scale),
        bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
    ) else { fail("could not create a bitmap context") }

    // Top-left origin, in points, like Finder's icon coordinates.
    cg.translateBy(x: 0, y: height * scale)
    cg.scaleBy(x: scale, y: -scale)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: cg, flipped: true)

    // Plate: warm off-white, a touch darker toward the bottom.
    let plate = NSGradient(colors: [rgb(0xFFFCF8), rgb(0xF7EFE7)])!
    plate.draw(in: NSRect(x: 0, y: 0, width: width, height: height), angle: 90)

    // The arrow: a shallow arc between the two icons, dashed shaft, open head.
    let start = CGPoint(x: appCenter.x + 88, y: appCenter.y - 4)
    let end = CGPoint(x: applicationsCenter.x - 88, y: applicationsCenter.y - 4)
    let control = CGPoint(x: (start.x + end.x) / 2, y: appCenter.y - 30)

    let shaft = NSBezierPath()
    shaft.move(to: start)
    shaft.curve(to: end, controlPoint1: control, controlPoint2: control)
    shaft.lineWidth = 2.5
    shaft.lineCapStyle = .round
    shaft.setLineDash([7, 7], count: 2, phase: 0)
    rgb(0xF27822).setStroke()
    shaft.stroke()

    // Head, aligned with the tangent of the curve at its end.
    let angle = atan2(end.y - control.y, end.x - control.x)
    let length: CGFloat = 11
    let spread: CGFloat = .pi / 4.5
    let head = NSBezierPath()
    head.move(to: CGPoint(x: end.x - length * cos(angle - spread), y: end.y - length * sin(angle - spread)))
    head.line(to: end)
    head.line(to: CGPoint(x: end.x - length * cos(angle + spread), y: end.y - length * sin(angle + spread)))
    head.lineWidth = 2.5
    head.lineCapStyle = .round
    head.lineJoinStyle = .round
    head.stroke()

    // The instruction.
    let centered = NSMutableParagraphStyle()
    centered.alignment = .center
    let title = NSAttributedString(string: "Drag Pyno to Applications", attributes: [
        .font: NSFont.systemFont(ofSize: 17, weight: .semibold),
        .foregroundColor: rgb(0x2B2420),
        .paragraphStyle: centered,
    ])
    title.draw(in: NSRect(x: 0, y: 328, width: width, height: 24))

    NSGraphicsContext.restoreGraphicsState()

    guard let image = cg.makeImage() else { fail("could not read the bitmap back") }
    let rep = NSBitmapImageRep(cgImage: image)
    rep.size = NSSize(width: width, height: height)
    guard let png = rep.representation(using: .png, properties: [:]) else { fail("could not encode \(path)") }
    try png.write(to: URL(fileURLWithPath: path))
}

try render(scale: 1, to: arguments[1])
try render(scale: 2, to: arguments[2])
