//
//  TimelineStrip.swift
//  SetSplitter
//
//  The app's signature element: the whole set as one horizontal strip, cut into
//  a segment per track in proportion to its length. On the Tracklist screen it
//  mirrors hover on the cards; on the Export screen the same strip fills with
//  accent as the export advances, so the "one long file becomes an album" idea
//  is literally visible.
//

import SwiftUI

struct TimelineStrip: View {

    /// Length of each track in seconds.
    let durations: [Double]
    let ids: [UUID]

    /// Overall 0…1 progress. `nil` shows the strip in its resting (preview) state.
    var progress: Double?

    @Binding var highlightedID: UUID?

    var height: CGFloat = 10
    private let gap: CGFloat = 2

    var body: some View {
        GeometryReader { geo in
            let layout = segments(width: geo.size.width)
            ZStack(alignment: .leading) {
                ForEach(layout, id: \.index) { seg in
                    segmentView(seg)
                        .frame(width: seg.width, height: height)
                        .offset(x: seg.x)
                }
            }
        }
        .frame(height: height)
        .animation(Theme.spring, value: durations)
        .accessibilityHidden(true)
    }

    // MARK: Segments

    private struct Segment { let index: Int; let x: CGFloat; let width: CGFloat; let start: Double; let length: Double }

    private func segments(width: CGFloat) -> [Segment] {
        let total = durations.reduce(0, +)
        guard total > 0, !durations.isEmpty else { return [] }
        let usable = max(0, width - gap * CGFloat(durations.count - 1))
        var x: CGFloat = 0
        var elapsed = 0.0
        return durations.enumerated().map { i, d in
            let w = max(2, usable * CGFloat(d / total))
            defer { x += w + gap; elapsed += d }
            return Segment(index: i, x: x, width: w, start: elapsed / total, length: d / total)
        }
    }

    @ViewBuilder
    private func segmentView(_ seg: Segment) -> some View {
        let isHighlighted = ids.indices.contains(seg.index) && ids[seg.index] == highlightedID
        let base = restingOpacity(seg.index)
        ZStack(alignment: .leading) {
            if let progress {
                // Export: track colour is a faint ghost; the filled part is full accent.
                Capsule().fill(Color.primary.opacity(0.10))
                let filled = min(1, max(0, (progress - seg.start) / max(seg.length, .leastNonzeroMagnitude)))
                Capsule().fill(Color.accentColor)
                    .frame(width: seg.width * filled)
                    .animation(.linear(duration: 0.12), value: filled)
            } else {
                Capsule().fill(Color.accentColor.opacity(isHighlighted ? 1 : base))
            }
        }
        .scaleEffect(y: isHighlighted ? 1.5 : 1)
        .animation(Theme.quick, value: isHighlighted)
        .contentShape(Rectangle())
        .onHover { inside in
            guard ids.indices.contains(seg.index) else { return }
            highlightedID = inside ? ids[seg.index] : (highlightedID == ids[seg.index] ? nil : highlightedID)
        }
    }

    /// Alternating tints keep neighbouring segments distinguishable while
    /// staying within one hue.
    private func restingOpacity(_ index: Int) -> Double {
        [0.9, 0.55, 0.75, 0.4][index % 4]
    }
}
