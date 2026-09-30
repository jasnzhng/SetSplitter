//
//  Tonearm.swift
//  SetSplitter
//
//  A turntable tonearm that can rest off the record, drop onto the outer groove,
//  and travel inward as `progress` grows, like a real one playing a side. The
//  geometry is solved once (law of cosines) so the needle tip really lands on the
//  requested groove radius, then the whole arm is *rotated* about its pivot, which
//  lets SwiftUI animate the swing.
//

import SwiftUI

struct Tonearm: View {

    enum Position: Equatable {
        /// Lifted and parked beside the record.
        case rest
        /// On the record. `progress` 0 is the outer groove, 1 the innermost.
        case playing(progress: Double)
    }

    /// Radius of the record this arm belongs to (points). The view is sized to the arm's reach.
    let recordRadius: CGFloat
    var position: Position = .rest

    // Geometry in units of the record radius, origin at the record centre, y down.
    private static let pivot = CGPoint(x: 1.22, y: -0.62)
    private static let armLength = 1.0
    private static let outerGroove = 0.94
    private static let innerGroove = 0.36   // just outside the label

    /// The arm angle (degrees, y-down, so increasing = clockwise) that puts the needle at `grooveRadius`.
    private static func angle(forGroove grooveRadius: Double) -> Double {
        let p = pivot
        let distance = hypot(p.x, p.y)
        let toCenter = atan2(-p.y, -p.x)
        let cosDelta = (distance * distance + armLength * armLength - grooveRadius * grooveRadius) / (2 * distance * armLength)
        return (toCenter - acos(min(1, max(-1, cosDelta)))) * 180 / .pi
    }

    private static let outerAngle = angle(forGroove: outerGroove)
    private static let innerAngle = angle(forGroove: innerGroove)
    private static let restAngle = outerAngle - 24

    private var currentAngle: Double {
        switch position {
        case .rest: Self.restAngle
        case .playing(let progress):
            Self.outerAngle + (Self.innerAngle - Self.outerAngle) * min(1, max(0, progress))
        }
    }

    var body: some View {
        // The arm is drawn once, at its rest angle, in a box that spans the record and the pivot.
        // Rotating it about the pivot moves the needle across the grooves.
        let r = recordRadius
        let width = r * 2.5, height = r * 2
        let origin = CGPoint(x: r, y: r)                       // record centre inside this box
        let pivotPoint = CGPoint(x: origin.x + Self.pivot.x * r, y: origin.y + Self.pivot.y * r)

        Canvas { canvas, _ in
            drawArm(in: &canvas, pivot: pivotPoint, radius: r)
        }
        .frame(width: width, height: height)
        .rotationEffect(.degrees(currentAngle - Self.restAngle),
                        anchor: UnitPoint(x: pivotPoint.x / width, y: pivotPoint.y / height))
        .animation(.smooth(duration: 0.9), value: position)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func drawArm(in canvas: inout GraphicsContext, pivot: CGPoint, radius r: CGFloat) {
        let theta = Self.restAngle * .pi / 180
        let direction = CGPoint(x: cos(theta), y: sin(theta))
        let tip = CGPoint(x: pivot.x + direction.x * r * Self.armLength, y: pivot.y + direction.y * r * Self.armLength)
        let tail = CGPoint(x: pivot.x - direction.x * r * 0.30, y: pivot.y - direction.y * r * 0.30)

        let metal = GraphicsContext.Shading.linearGradient(
            Gradient(colors: [Color(white: 0.92), Color(white: 0.62)]),
            startPoint: CGPoint(x: pivot.x - r * 0.1, y: pivot.y - r * 0.1),
            endPoint: CGPoint(x: pivot.x + r * 0.1, y: pivot.y + r * 0.1))

        // Soft shadow under the arm so it reads as lifted above the record.
        var shadow = Path(); shadow.move(to: tail); shadow.addLine(to: tip)
        canvas.stroke(shadow.offsetBy(dx: r * 0.03, dy: r * 0.05), with: .color(.black.opacity(0.28)),
                      style: StrokeStyle(lineWidth: r * 0.035, lineCap: .round))

        // Tube + counterweight.
        var tube = Path(); tube.move(to: tail); tube.addLine(to: tip)
        canvas.stroke(tube, with: metal, style: StrokeStyle(lineWidth: r * 0.032, lineCap: .round))
        var weight = Path(); weight.move(to: tail); weight.addLine(to: CGPoint(x: pivot.x - direction.x * r * 0.12, y: pivot.y - direction.y * r * 0.12))
        canvas.stroke(weight, with: .color(Color(white: 0.30)), style: StrokeStyle(lineWidth: r * 0.09, lineCap: .round))

        // Headshell at the tip, with an accent-coloured cartridge.
        var head = Path(); head.move(to: tip); head.addLine(to: CGPoint(x: tip.x + direction.x * r * 0.13, y: tip.y + direction.y * r * 0.13))
        canvas.stroke(head, with: .color(Color(white: 0.20)), style: StrokeStyle(lineWidth: r * 0.075, lineCap: .round))
        canvas.fill(Path(ellipseIn: CGRect(x: tip.x + direction.x * r * 0.10 - r * 0.02, y: tip.y + direction.y * r * 0.10 - r * 0.02,
                                           width: r * 0.04, height: r * 0.04)), with: .color(ArtPalette.coral))

        // Pivot base.
        canvas.fill(Path(ellipseIn: CGRect(x: pivot.x - r * 0.095, y: pivot.y - r * 0.095, width: r * 0.19, height: r * 0.19)),
                    with: .color(Color(white: 0.22)))
        canvas.fill(Path(ellipseIn: CGRect(x: pivot.x - r * 0.05, y: pivot.y - r * 0.05, width: r * 0.10, height: r * 0.10)),
                    with: metal)
    }
}
