//
//  LivingBackdrop.swift
//  SetSplitter
//
//  A slow, soft colour field behind the whole window: three large soft-edged
//  discs drifting on Lissajous paths. Colours crossfade when the palette
//  changes. It is static under Reduce Motion, and pauses while the window is
//  inactive so it costs nothing in the background.
//

import SwiftUI

struct LivingBackdrop: View {

    let palette: ArtPalette

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion || scenePhase != .active)) { context in
            let t = reduceMotion ? 0 : context.date.timeIntervalSinceReferenceDate
            GeometryReader { geo in
                ZStack {
                    ForEach(Array(palette.colors.enumerated()), id: \.offset) { index, color in
                        blob(color, index: index, time: t, in: geo.size)
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height)
                .opacity(colorScheme == .dark ? 0.62 : 0.5)
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .animation(.smooth(duration: 1.4), value: palette)   // colours crossfade between steps / covers
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// One drifting disc. Speeds and phases differ per index so the field never repeats visibly.
    private func blob(_ color: Color, index: Int, time: Double, in size: CGSize) -> some View {
        let i = Double(index)
        let diameter = min(size.width, size.height) * (0.85 - i * 0.12)
        let x = cos(time * (0.045 + i * 0.013) + i * 2.1) * size.width * 0.28
        let y = sin(time * (0.038 + i * 0.011) + i * 1.3) * size.height * 0.26
        // A radial gradient that fades to clear is the soft edge: no blur filter needed, so it is
        // cheap to redraw every frame and renders the same in snapshots.
        return Circle()
            .fill(RadialGradient(colors: [color, color.opacity(0.55), color.opacity(0)],
                                 center: .center, startRadius: 0, endRadius: diameter / 2))
            .frame(width: diameter, height: diameter)
            .offset(x: x + (i - 1) * size.width * 0.18, y: y + (1 - i) * size.height * 0.1)
    }
}
