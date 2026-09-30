//
//  ExportProgressPanel.swift
//  SetSplitter
//
//  The running state of the Export screen, staged as a turntable: the record spins,
//  its label is the album cover, track gaps are cut into the grooves where the set
//  splits, and the tonearm travels inward as the export advances. Beside it: the
//  percentage, the current track, and Cancel. Below: the timeline strip filling in.
//

import SwiftUI
import SetSplitterCore

struct ExportProgressPanel: View {

    let progress: ExportProgress
    let onCancel: () -> Void

    @Environment(SessionStore.self) private var store
    @State private var highlighted: Timestamp?

    var body: some View {
        VStack(spacing: 30) {
            HStack(spacing: 44) {
                Turntable(
                    state: .exporting(progress: progress.fraction), radius: 128,
                    palette: store.backdropPalette, trackGaps: trackGaps, labelImage: store.artwork?.image)

                // Combined so VoiceOver reads one progress summary; Cancel stays a separate,
                // focusable element.
                VStack(alignment: .leading, spacing: 10) {
                    Text(percent)
                        .font(.display(76, weight: .ultraLight).monospacedDigit())
                        .contentTransition(.numericText(value: progress.fraction))
                        .animation(.smooth(duration: 0.3), value: percent)
                        .accessibilityHidden(true)
                    Text(progress.phase == .finalizing ? "Finishing up…" : "Track \(progress.currentTrack) of \(progress.trackCount)")
                        .font(.system(size: 15, weight: .medium, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .contentTransition(.numericText())
                        .animation(Theme.quick, value: progress.currentTrack)
                        .accessibilityHidden(true)
                    Text(progress.currentTitle)
                        .font(.callout)
                        .foregroundStyle(.tertiary)
                        .lineLimit(2)
                        .truncationMode(.middle)
                        .frame(maxWidth: 300, alignment: .leading)
                        .animation(Theme.quick, value: progress.currentTitle)
                        .accessibilityHidden(true)
                    Button("Cancel", role: .cancel, action: onCancel)
                        .controlSize(.large)
                        .glassButtonStyle()
                        .keyboardShortcut(.cancelAction)
                        .padding(.top, 8)
                }
                .accessibilityElement(children: .contain)
                .accessibilityLabel("Exporting, \(percent). Track \(progress.currentTrack) of \(progress.trackCount).")
            }

            TimelineStrip(
                durations: strip.durations, ids: strip.ids, progress: progress.fraction,
                highlightedID: $highlighted, height: 12)
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .glassCapsule()
                .frame(maxWidth: 600)
        }
        .padding(Theme.pagePadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var percent: String { "\(Int((progress.fraction * 100).rounded()))%" }

    /// Where each track after the first begins, as a fraction of the whole set — cut into the record as gaps.
    private var trackGaps: [Double] {
        let durations = store.durations
        let total = durations.reduce(0, +)
        guard durations.count > 1, total > 0 else { return [] }
        var running = 0.0
        return durations.dropLast().map { d in running += d; return running / total }
    }

    /// The same segments the preview showed. With no tracklist there's one.
    private var strip: (durations: [Double], ids: [Timestamp]) {
        if store.tracks.isEmpty { return ([store.source?.info.duration ?? 1], [Timestamp(seconds: 0)]) }
        return (store.durations, store.tracks.map(\.start))
    }
}
