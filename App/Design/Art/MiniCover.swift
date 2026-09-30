//
//  MiniCover.swift
//  SetSplitter
//
//  A tiny generated album cover for one track: a curated gradient plus one of a
//  handful of graphic motifs, both chosen deterministically from a seed string
//  (the track's title and artist). The same track always gets the same cover, so
//  the list reads like a record library rather than a column of numbers.
//

import SwiftUI

struct MiniCover: View {

    let seed: String
    var size: CGFloat = 36
    /// Shown small in the corner so the track number isn't lost.
    var number: Int?

    var body: some View {
        let hash = Self.fnv1a(seed)
        let scheme = Self.schemes[Int(hash % UInt64(Self.schemes.count))]
        let motif = Int((hash >> 8) % 5)
        let variation = Double((hash >> 16) % 100) / 100

        Canvas { canvas, canvasSize in
            let rect = CGRect(origin: .zero, size: canvasSize)
            canvas.fill(Path(rect), with: .linearGradient(
                Gradient(colors: [scheme.0, scheme.1]),
                startPoint: CGPoint(x: 0, y: 0), endPoint: CGPoint(x: canvasSize.width, y: canvasSize.height)))
            draw(motif: motif, variation: variation, in: &canvas, rect: rect)
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.17, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: size * 0.17, style: .continuous).strokeBorder(.white.opacity(0.18), lineWidth: 0.5))
        .overlay(alignment: .bottomLeading) {
            if let number {
                Text("\(number)")
                    .font(.system(size: size * 0.27, weight: .heavy, design: .rounded).monospacedDigit())
                    .foregroundStyle(.white.opacity(0.92))
                    .shadow(color: .black.opacity(0.35), radius: 1)
                    .padding(size * 0.08)
            }
        }
        .accessibilityHidden(true)
    }

    // MARK: Motifs

    private func draw(motif: Int, variation v: Double, in canvas: inout GraphicsContext, rect: CGRect) {
        let w = rect.width, h = rect.height
        let ink = Color.white.opacity(0.55)
        switch motif {
        case 0:   // concentric rings, off-centre
            let c = CGPoint(x: w * (0.3 + v * 0.4), y: h * 0.6)
            for i in 1...4 {
                let r = CGFloat(i) * w * 0.16
                canvas.stroke(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)),
                              with: .color(ink), lineWidth: w * 0.035)
            }
        case 1:   // mini waveform
            let bars = 7
            for i in 0..<bars {
                let phase = sin(Double(i) * (0.9 + v) + v * 6)
                let bh = h * (0.22 + 0.5 * abs(phase))
                let bw = w * 0.075
                let x = w * 0.16 + CGFloat(i) * (w * 0.68 / CGFloat(bars - 1)) - bw / 2
                canvas.fill(Path(roundedRect: CGRect(x: x, y: (h - bh) / 2, width: bw, height: bh), cornerRadius: bw / 2), with: .color(ink))
            }
        case 2:   // sun over a horizon
            let r = w * (0.2 + v * 0.1)
            canvas.fill(Path(ellipseIn: CGRect(x: w * 0.5 - r, y: h * 0.5 - r, width: r * 2, height: r * 2)), with: .color(ink))
            canvas.fill(Path(CGRect(x: 0, y: h * 0.62, width: w, height: h * 0.38)), with: .color(.black.opacity(0.28)))
        case 3:   // diagonal split
            var path = Path()
            path.move(to: CGPoint(x: w, y: 0)); path.addLine(to: CGPoint(x: w, y: h)); path.addLine(to: CGPoint(x: w * (0.25 + v * 0.3), y: h)); path.closeSubpath()
            canvas.fill(path, with: .color(.black.opacity(0.22)))
            canvas.fill(Path(ellipseIn: CGRect(x: w * 0.18, y: h * 0.18, width: w * 0.3, height: w * 0.3)), with: .color(ink))
        default:  // dot grid
            let n = 4
            for row in 0..<n {
                for col in 0..<n {
                    let r = w * 0.045 * (1 + 0.6 * sin(Double(row * n + col) * (1 + v)))
                    let cx = w * (0.2 + 0.2 * CGFloat(col)), cy = h * (0.2 + 0.2 * CGFloat(row))
                    canvas.fill(Path(ellipseIn: CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2)), with: .color(ink))
                }
            }
        }
    }

    // MARK: Seed → colour

    /// Curated pairs (not random hues), so every cover looks like it belongs to the same label.
    private static let schemes: [(Color, Color)] = [
        (Color(red: 1.00, green: 0.42, blue: 0.30), Color(red: 0.42, green: 0.25, blue: 0.63)),
        (Color(red: 0.98, green: 0.72, blue: 0.36), Color(red: 0.90, green: 0.30, blue: 0.42)),
        (Color(red: 0.30, green: 0.78, blue: 0.75), Color(red: 0.20, green: 0.24, blue: 0.62)),
        (Color(red: 0.62, green: 0.45, blue: 1.00), Color(red: 0.98, green: 0.42, blue: 0.62)),
        (Color(red: 0.96, green: 0.84, blue: 0.50), Color(red: 0.86, green: 0.44, blue: 0.30)),
        (Color(red: 0.36, green: 0.62, blue: 0.98), Color(red: 0.56, green: 0.30, blue: 0.80)),
        (Color(red: 0.40, green: 0.82, blue: 0.56), Color(red: 0.14, green: 0.42, blue: 0.50)),
        (Color(red: 0.98, green: 0.56, blue: 0.44), Color(red: 0.62, green: 0.20, blue: 0.40)),
    ]

    /// 64-bit FNV-1a: a tiny, stable hash. (`String.hashValue` is randomised per launch, which
    /// would give a track a different cover every time the app opens.)
    static func fnv1a(_ text: String) -> UInt64 {
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in text.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x100000001b3
        }
        return hash
    }
}
