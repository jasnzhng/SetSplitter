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

    let model: TracklistViewModel
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

    let model: TracklistViewModel
    @Environment(SessionStore.self) private var store

    var body: some View {
        @Bindable var store = store
        VStack(alignment: .leading, spacing: 8) {
            // The count sits under the title (not below the box) so the editor's bottom edge lines up
            // with the preview list on the right.
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    SectionLabel("Tracklist")
                    Text(footerText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .contentTransition(.numericText())
                        .animation(Theme.quick, value: store.parseResult.tracks.count)
                }
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
                    // Sits where the editor's first line does: its 8 pt padding plus the text view's
                    // 5 pt line-fragment padding across, and no top inset, so the caret lines up.
                    placeholder
                        .padding(.leading, 13)
                        .padding(.top, 8)
                        .allowsHitTesting(false)
                }
            }
            .card()
            .accessibilityLabel("Tracklist text")
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

    @Bindable var model: TracklistViewModel   // needs `$model.highlightedStart`
    @Environment(SessionStore.self) private var store

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                SectionLabel("Preview")
                Spacer()
                if !store.tracks.isEmpty {
                    Text("\(store.tracks.count) \(store.tracks.count == 1 ? "track" : "tracks") · \(TrackTiming.format(store.source?.info.duration ?? 0))")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .contentTransition(.numericText())
                }
            }

            if store.tracks.isEmpty {
                emptyState
            } else {
                TimelineStrip(
                    durations: store.durations, ids: store.tracks.map(\.start),
                    highlightedID: $model.highlightedStart)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .glassCapsule()

                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(Array(zip(store.tracks, store.durations).enumerated()), id: \.element.0.start) { index, pair in
                            let (track, duration) = pair
                            TrackPreviewCard(
                                track: track, duration: duration,
                                isHighlighted: model.highlightedStart == track.start,
                                onTitle: { model.setTitle($0, for: track) },
                                onArtist: { model.setArtist($0, for: track) },
                                onRevert: { model.revert(track) })
                                .onHover { inside in
                                    if inside { model.highlightedStart = track.start }
                                    else if model.highlightedStart == track.start { model.highlightedStart = nil }
                                }
                                // New cards rise in one after another, like sleeves being dealt onto a table.
                                .transition(.opacity.combined(with: .offset(y: 14))
                                    .animation(.smooth(duration: 0.4).delay(Double(min(index, 10)) * 0.045)))
                        }
                    }
                    .padding(.vertical, 2)
                    .padding(.trailing, 2)
                }
                .scrollIndicators(.automatic)
                .moreBelowBlur()
                .frame(maxHeight: .infinity)
            }

            WarningsList(warnings: store.warnings)
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .animation(Theme.smooth, value: store.tracks.isEmpty)
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
