//
//  VinylRecord.swift
//  SetSplitter
//
//  A drawn record: near-black disc, fine grooves, a rotating sheen, and a
//  coloured centre label. Drawn with Canvas (no image assets), so it scales
//  crisply and takes its label colours from the current palette. It only
//  spins while `isSpinning`, and never under Reduce Motion.
//

import SwiftUI

struct VinylRecord: View {

    /// Diameter of the whole disc.
    let size: CGFloat
    var isSpinning = false
    /// Label gradient, typically the first two palette colours.
    var labelColors: [Color] = [ArtPalette.coral, ArtPalette.plum]
    /// Fractions (0…1) of the groove area at which to draw a track-gap band.
    var trackGaps: [Double] = []

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Degrees per second of the sheen while spinning (a 33⅓ rpm record is 200°/s; this is calmer).
    private let degreesPerSecond = 60.0

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !isSpinning || reduceMotion)) { context in
            let angle = isSpinning && !reduceMotion
                ? (context.date.timeIntervalSinceReferenceDate * degreesPerSecond).truncatingRemainder(dividingBy: 360)
                : 0
            Canvas { canvas, canvasSize in
                draw(in: &canvas, size: canvasSize, sheenAngle: angle)
            }
        }
        .frame(width: size, height: size)
        .shadow(color: .black.opacity(0.35), radius: size * 0.06, y: size * 0.03)
        .accessibilityHidden(true)
    }

    // MARK: Drawing

    private func draw(in canvas: inout GraphicsContext, size canvasSize: CGSize, sheenAngle: Double) {
        let radius = min(canvasSize.width, canvasSize.height) / 2
        let center = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
        func circle(_ r: CGFloat) -> Path {
            Path(ellipseIn: CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2))
        }

        // Disc body.
        canvas.fill(circle(radius), with: .radialGradient(
            Gradient(colors: [Color(white: 0.16), Color(white: 0.07)]),
            center: center, startRadius: 0, endRadius: radius))

        // Grooves: hairline rings between the label and the rim, alternating strength.
        let inner = radius * 0.36, outer = radius * 0.965
        var r = inner + 3
        var step = 0
        while r < outer {
            canvas.stroke(circle(r), with: .color(.white.opacity(step.isMultiple(of: 3) ? 0.075 : 0.035)), lineWidth: 0.5)
            r += 2.6
            step += 1
        }

        // Track gaps: a slightly wider, smoother band where one track ends and the next begins.
        for gap in trackGaps {
            let gr = inner + (outer - inner) * (1 - gap)
            canvas.stroke(circle(gr), with: .color(.black.opacity(0.55)), lineWidth: 2.4)
            canvas.stroke(circle(gr + 1.6), with: .color(.white.opacity(0.10)), lineWidth: 0.6)
        }

        // Sheen: two soft light wedges that rotate with the record.
        let sheen = Gradient(stops: [
            .init(color: .clear, location: 0.00), .init(color: .white.opacity(0.16), location: 0.06),
            .init(color: .clear, location: 0.14), .init(color: .clear, location: 0.50),
            .init(color: .white.opacity(0.10), location: 0.56), .init(color: .clear, location: 0.64),
            .init(color: .clear, location: 1.00),
        ])
        var sheenContext = canvas
        sheenContext.clip(to: circle(outer).subtracting(circle(inner)))
        sheenContext.fill(circle(radius), with: .conicGradient(sheen, center: center, angle: .degrees(sheenAngle)))

        // Rim highlight.
        canvas.stroke(circle(radius - 0.5), with: .color(.white.opacity(0.12)), lineWidth: 1)

        // Label.
        let labelRadius = radius * 0.34
        canvas.fill(circle(labelRadius), with: .linearGradient(
            Gradient(colors: labelColors.isEmpty ? [ArtPalette.coral] : labelColors),
            startPoint: CGPoint(x: center.x - labelRadius, y: center.y - labelRadius),
            endPoint: CGPoint(x: center.x + labelRadius, y: center.y + labelRadius)))
        canvas.stroke(circle(labelRadius * 0.86), with: .color(.white.opacity(0.22)), lineWidth: 0.6)
        canvas.stroke(circle(labelRadius * 0.62), with: .color(.white.opacity(0.14)), lineWidth: 0.5)

        // Spindle hole.
        canvas.fill(circle(radius * 0.028), with: .color(Color(white: 0.05)))
    }
}
