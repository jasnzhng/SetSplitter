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
        // Layout size is the record alone, so the record (not record + arm) is what
        // centres in its parent; the arm overhangs to the right via the overlay.
        VinylRecord(size: radius * 2, isSpinning: isSpinning,
                    labelColors: Array(palette.colors.prefix(2)), trackGaps: trackGaps)
            .scaleEffect(state == .targeted ? 1.04 : 1)
            .animation(Theme.smooth, value: state == .targeted)
            .frame(width: radius * 2, height: radius * 2)
            .overlay(alignment: .topLeading) {
                Tonearm(recordRadius: radius, position: armPosition)
            }
    }
}
