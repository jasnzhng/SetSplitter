//
//  TracklistScreen.swift
//  SetSplitter
//
//  Step 2. Left: the pasted tracklist. Right: parsing options, then the live
//  preview (timeline strip + one card per track) and any warnings.
//

import SwiftUI
import SetSplitterCore

struct TracklistScreen: View {

    @Bindable var model: TracklistViewModel
    @Environment(SessionStore.self) private var store

    var body: some View {
        @Bindable var store = store
        HStack(alignment: .top, spacing: 20) {
            TracklistEditor(model: model)
                .frame(minWidth: 300, idealWidth: 340, maxWidth: 380)

            VStack(alignment: .leading, spacing: 14) {
                ParseOptionsPanel(options: $store.parseOptions)
                PreviewSection(model: model)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, Theme.pagePadding)
        .padding(.vertical, 20)
    }
}

// MARK: - Left column

private struct TracklistEditor: View {

    @Bindable var model: TracklistViewModel
    @Environment(SessionStore.self) private var store

    var body: some View {
        @Bindable var store = store
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                SectionLabel("Tracklist")
                Spacer()
                Button("Paste", systemImage: "doc.on.clipboard", action: model.pasteFromClipboard)
                Button("Clear", systemImage: "xmark.circle", action: model.clearText)
                    .disabled(store.tracklistText.isEmpty)
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.borderless)
            .controlSize(.regular)

            ZStack(alignment: .topLeading) {
                TextEditor(text: $store.tracklistText)
                    .font(.system(size: 12, design: .monospaced))
                    .scrollContentBackground(.hidden)
                    .padding(8)
                if store.tracklistText.isEmpty {
                    placeholder
                        .padding(14)
                        .allowsHitTesting(false)
                }
            }
            .card()
            .accessibilityLabel("Tracklist text")

            Text(footerText)
                .font(.caption)
                .foregroundStyle(.secondary)
                .contentTransition(.numericText())
                .animation(Theme.quick, value: store.parseResult.tracks.count)
        }
    }

    private var placeholder: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Paste your tracklist")
                .font(.system(size: 13, weight: .medium))
            Text("0:00 Artist - Title\n4:12 Artist ft. Guest - Title (Remix)\n8:30 Artist - Title")
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.tertiary)
            Text("Any layout works, even one long line. Timestamps mark where each track starts.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var footerText: String {
        let n = store.parseResult.tracks.count
        if store.tracklistText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "No tracklist: the set exports as a single track."
        }
        return n == 1 ? "1 timestamp found" : "\(n) timestamps found"
    }
}

// MARK: - Right column: preview

private struct PreviewSection: View {

    @Bindable var model: TracklistViewModel
    @Environment(SessionStore.self) private var store

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                SectionLabel("Preview")
                Spacer()
                if !store.tracks.isEmpty {
                    Text("\(store.tracks.count) tracks · \(TrackTiming.format(store.source?.info.duration ?? 0))")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .contentTransition(.numericText())
                }
            }

            if store.tracks.isEmpty {
                emptyState
            } else {
                TimelineStrip(
                    durations: store.durations, ids: store.tracks.map(\.id),
                    highlightedID: $model.highlightedTrackID)
                    .padding(.vertical, 4)

                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 6) {
                            ForEach(Array(zip(store.tracks, store.durations)), id: \.0.start) { track, duration in
                                TrackPreviewCard(
                                    track: track, duration: duration,
                                    isHighlighted: model.highlightedTrackID == track.id,
                                    onTitle: { model.setTitle($0, for: track) },
                                    onArtist: { model.setArtist($0, for: track) },
                                    onRevert: { model.revert(track) })
                                    .id(track.id)
                                    .onHover { inside in
                                        if inside { model.highlightedTrackID = track.id }
                                        else if model.highlightedTrackID == track.id { model.highlightedTrackID = nil }
                                    }
                            }
                        }
                        .padding(.vertical, 2)
                        .padding(.trailing, 2)
                    }
                    .scrollIndicators(.automatic)
                }
                .frame(maxHeight: .infinity)
            }

            WarningsList(warnings: store.warnings)
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .animation(Theme.spring, value: store.tracks.isEmpty)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "list.bullet.rectangle")
                .font(.system(size: 30, weight: .light))
                .foregroundStyle(.tertiary)
            Text("Tracks appear here as you paste.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .card()
    }
}
