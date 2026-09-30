//
//  ExportProgressPanel.swift
//  SetSplitter
//
//  The running state of the Export screen: a big percentage, the current
//  track, and the timeline strip filling in as the set is cut into tracks.
//

import SwiftUI
import SetSplitterCore

struct ExportProgressPanel: View {

    let progress: ExportProgress
    let onCancel: () -> Void

    @Environment(SessionStore.self) private var store
    @State private var highlighted: Timestamp?

    var body: some View {
        VStack(spacing: 26) {
            // Combined so VoiceOver reads one progress summary; the Cancel button
            // below stays a separate, focusable element.
            VStack(spacing: 4) {
                Text(percent)
                    .font(.display(76, weight: .ultraLight).monospacedDigit())
                    .contentTransition(.numericText(value: progress.fraction))
                    .animation(.smooth(duration: 0.3), value: percent)
                Text(progress.phase == .finalizing ? "Finishing up…" : "Track \(progress.currentTrack) of \(progress.trackCount)")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
                    .animation(Theme.quick, value: progress.currentTrack)
                Text(progress.currentTitle)
                    .font(.callout)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: 420)
                    .animation(Theme.quick, value: progress.currentTitle)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Exporting, \(percent). Track \(progress.currentTrack) of \(progress.trackCount).")

            TimelineStrip(
                durations: strip.durations, ids: strip.ids, progress: progress.fraction,
                highlightedID: $highlighted, height: 12)
                .frame(maxWidth: 560)

            Button("Cancel", role: .cancel, action: onCancel)
                .controlSize(.large)
                .keyboardShortcut(.cancelAction)
        }
        .padding(Theme.pagePadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var percent: String { "\(Int((progress.fraction * 100).rounded()))%" }

    /// The same segments the preview showed. With no tracklist there's one.
    private var strip: (durations: [Double], ids: [Timestamp]) {
        if store.tracks.isEmpty { return ([store.source?.info.duration ?? 1], [Timestamp(seconds: 0)]) }
        return (store.durations, store.tracks.map(\.start))
    }
}
