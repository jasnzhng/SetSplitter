//
//  Turntable.swift
//  SetSplitter
//
//  A record and its tonearm composed at the right proportions. Callers describe
//  what's happening (`state`), and the record spins / the arm swings to match.
//

import SwiftUI

struct Turntable: View {

    enum State: Equatable {
        /// Nothing loaded: still record, arm parked.
        case idle
        /// A file is being dragged over: the arm drops and the record starts to turn.
        case targeted
        /// Reading a file.
        case loading
        /// A set is loaded and "playing": spinning, arm resting on the outer groove.
        case loaded
        /// Exporting: spinning, arm travelling inward with `progress` (0…1).
        case exporting(progress: Double)
    }

    let state: State
    /// Radius of the record.
    var radius: CGFloat = 130
    var palette: ArtPalette = .resting(for: .importFile)
    var trackGaps: [Double] = []
    /// Static text shown on the label (it does not spin, so it stays legible).
    var labelText: String?

    private var isSpinning: Bool {
        switch state {
        case .idle: false
        default: true
        }
    }

    private var armPosition: Tonearm.Position {
        switch state {
        case .idle: .rest
        case .targeted, .loading, .loaded: .playing(progress: 0.02)
        case .exporting(let progress): .playing(progress: progress)
        }
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            VinylRecord(size: radius * 2, isSpinning: isSpinning,
                        labelColors: Array(palette.colors.prefix(2)), trackGaps: trackGaps)
                .overlay {
                    if let labelText {
                        Text(labelText)
                            .font(.display(radius * 0.105, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.95))
                            .shadow(color: .black.opacity(0.35), radius: 1, y: 0.5)
                            .minimumScaleFactor(0.6)
                            .lineLimit(1)
                            .frame(width: radius * 0.5)
                            .offset(y: -radius * 0.09)   // above the spindle hole
                    }
                }
                .scaleEffect(state == .targeted ? 1.04 : 1)
                .animation(Theme.smooth, value: state == .targeted)
            Tonearm(recordRadius: radius, position: armPosition)
        }
        .frame(width: radius * 2.5, height: radius * 2, alignment: .topLeading)
    }
}
