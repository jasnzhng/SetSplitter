//
//  EqualizerBars.swift
//  SetSplitter
//
//  A tiny animated equalizer: a few bars bouncing out of phase. Purely a "this is
//  working" cue, so it stops (and rests at mid height) under Reduce Motion.
//

import SwiftUI

struct EqualizerBars: View {

    var barCount = 4
    var height: CGFloat = 14
    var color: Color = .accentColor

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 24.0, paused: reduceMotion)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            HStack(alignment: .center, spacing: 2.5) {
                ForEach(0..<barCount, id: \.self) { i in
                    let level = reduceMotion ? 0.55 : 0.35 + 0.65 * abs(sin(t * (2.2 + Double(i) * 0.7) + Double(i) * 1.3))
                    Capsule()
                        .fill(color)
                        .frame(width: 3, height: height * level)
                }
            }
            .frame(height: height)
        }
        .accessibilityHidden(true)
    }
}
