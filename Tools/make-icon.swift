#!/usr/bin/env swift
//
//  make-icon.swift
//  Renders the SetSplitter app icon (a waveform sliced in two) with CoreGraphics
//  and writes the full macOS AppIcon set + Contents.json.
//
//      swift Tools/make-icon.swift App/Resources/Assets.xcassets/AppIcon.appiconset Tools/icon-preview.png
//
//  macOS does not mask app icons, so the rounded-square body, its inset from the
//  1024 canvas and its soft shadow are all drawn here.
//

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let outDir = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? ".")
let space = CGColorSpace(name: CGColorSpace.sRGB)!

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(colorSpace: space, components: [
        CGFloat((hex >> 16) & 0xFF) / 255, CGFloat((hex >> 8) & 0xFF) / 255, CGFloat(hex & 0xFF) / 255, alpha,
    ])!
}

func render(size: Int) -> CGImage {
    let s = CGFloat(size) / 1024
    let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0, space: space,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.scaleBy(x: s, y: s)
    ctx.interpolationQuality = .high

    // Body: 824 pt squircle, centred, with Apple's ~22.4% corner radius.
    let body = CGRect(x: 100, y: 100, width: 824, height: 824)
    let path = CGPath(roundedRect: body, cornerWidth: 185, cornerHeight: 185, transform: nil)

    // Soft drop shadow.
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -14), blur: 34, color: color(0x000000, 0.35))
    ctx.setFillColor(color(0x1A1326))
    ctx.addPath(path); ctx.fillPath()
    ctx.restoreGState()

    // Body gradient: deep aubergine to near-black.
    ctx.saveGState()
    ctx.addPath(path); ctx.clip()
    let bg = CGGradient(colorsSpace: space, colors: [color(0x3A2350), color(0x14101F)] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(bg, start: CGPoint(x: 300, y: 924), end: CGPoint(x: 724, y: 100),
                           options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])

    // Soft warm glow behind the waveform.
    let glow = CGGradient(colorsSpace: space, colors: [color(0xFF6A4D, 0.30), color(0xFF6A4D, 0)] as CFArray, locations: [0, 1])!
    ctx.drawRadialGradient(glow, startCenter: CGPoint(x: 512, y: 512), startRadius: 0,
                           endCenter: CGPoint(x: 512, y: 512), endRadius: 420, options: [])

    // Waveform: 15 rounded bars. The cut falls *between* bars 7 and 8: the left group stays put
    // in coral; the right group slips down and away in cream, as if the set were sliced in two.
    let heights: [CGFloat] = [120, 210, 300, 190, 380, 260, 470, 330, 420, 240, 350, 170, 260, 140, 90]
    let barWidth: CGFloat = 30, gap: CGFloat = 20, cutGap: CGFloat = 34
    let cutIndex = 7                      // bars [0, cutIndex) are the left half
    let total = CGFloat(heights.count) * barWidth + CGFloat(heights.count - 1) * gap + cutGap
    let startX = 512 - total / 2

    func drawBars(_ range: Range<Int>, dx: CGFloat, dy: CGFloat, gradient: CGGradient) {
        ctx.saveGState()
        for i in range {
            let h = heights[i]
            let x = startX + CGFloat(i) * (barWidth + gap) + (i >= cutIndex ? cutGap : 0) + dx
            let rect = CGRect(x: x, y: 512 - h / 2 + dy, width: barWidth, height: h)
            ctx.addPath(CGPath(roundedRect: rect, cornerWidth: barWidth / 2, cornerHeight: barWidth / 2, transform: nil))
        }
        ctx.clip()
        ctx.drawLinearGradient(gradient, start: CGPoint(x: 0, y: 800 + dy), end: CGPoint(x: 0, y: 220 + dy),
                               options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
        ctx.restoreGState()
    }

    let coral = CGGradient(colorsSpace: space, colors: [color(0xFF8A6A), color(0xE4472D)] as CFArray, locations: [0, 1])!
    let cream = CGGradient(colorsSpace: space, colors: [color(0xFFF3E6), color(0xFFD2B0)] as CFArray, locations: [0, 1])!
    drawBars(0..<cutIndex, dx: 0, dy: 0, gradient: coral)
    drawBars(cutIndex..<heights.count, dx: 0, dy: -46, gradient: cream)

    ctx.restoreGState()   // body clip

    // Hairline highlight on the body's edge.
    ctx.saveGState()
    ctx.addPath(path)
    ctx.setStrokeColor(color(0xFFFFFF, 0.10))
    ctx.setLineWidth(2)
    ctx.strokePath()
    ctx.restoreGState()

    return ctx.makeImage()!
}

func write(_ image: CGImage, to url: URL) {
    let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, image, nil)
    precondition(CGImageDestinationFinalize(dest), "couldn't write \(url.path)")
}

// (point size, scale) pairs required for a macOS app icon.
let variants: [(Int, Int)] = [(16, 1), (16, 2), (32, 1), (32, 2), (128, 1), (128, 2), (256, 1), (256, 2), (512, 1), (512, 2)]
var images: [[String: String]] = []
for (points, scale) in variants {
    let px = points * scale
    let name = "icon_\(points)x\(points)@\(scale)x.png"
    write(render(size: px), to: outDir.appendingPathComponent(name))
    images.append(["idiom": "mac", "size": "\(points)x\(points)", "scale": "\(scale)x", "filename": name])
}
let contents: [String: Any] = ["images": images, "info": ["author": "xcode", "version": 1]]
let data = try! JSONSerialization.data(withJSONObject: contents, options: [.prettyPrinted, .sortedKeys])
try! data.write(to: outDir.appendingPathComponent("Contents.json"))
if CommandLine.arguments.count > 2 {   // optional 1024 px preview for docs / review
    write(render(size: 1024), to: URL(fileURLWithPath: CommandLine.arguments[2]))
}
print("wrote \(variants.count) icons to \(outDir.path)")
