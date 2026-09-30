//
//  TrackPreviewCard.swift
//  SetSplitter
//
//  One track, styled like a Music app row: artwork tile with the track number,
//  bold title over secondary artist, monospaced duration on the right. Title
//  and artist edit inline (§12 Phase 4).
//

import SwiftUI
import SetSplitterCore

struct TrackPreviewCard: View {

    let track: ParsedTrack
    let duration: Double
    let isHighlighted: Bool
    let onTitle: (String) -> Void
    let onArtist: (String) -> Void
    let onRevert: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            numberTile

            VStack(alignment: .leading, spacing: 1) {
                InlineEditableText(
                    text: track.title, placeholder: "Untitled",
                    font: .system(size: 13, weight: .semibold), onCommit: onTitle)
                InlineEditableText(
                    text: track.artist, placeholder: "Unknown artist",
                    font: .system(size: 12), color: .secondary, onCommit: onArtist)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if !track.warnings.isEmpty {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.yellow)
                    .help(track.warnings.map(\.message).joined(separator: "\n"))
                    .accessibilityLabel(track.warnings.map(\.message).joined(separator: ". "))
            }

            Text(TrackTiming.format(duration))
                .font(.system(size: 12).monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(minWidth: 40, alignment: .trailing)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Theme.rowRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.rowRadius, style: .continuous)
                .strokeBorder(isHighlighted ? Color.accentColor.opacity(0.7) : Color(nsColor: .separatorColor).opacity(0.5),
                              lineWidth: isHighlighted ? 1.25 : 0.5)
        )
        .scaleEffect(isHighlighted ? 1.012 : 1)
        .shadow(color: .black.opacity(isHighlighted ? 0.18 : 0), radius: 8, y: 3)
        .animation(Theme.quick, value: isHighlighted)
        .contextMenu {
            if track.userEdited {
                Button("Revert to Parsed Text", systemImage: "arrow.uturn.backward", action: onRevert)
            }
            Text("Starts at \(track.start.displayString)")
        }
        .accessibilityElement(children: .contain)   // keep the inline editors individually reachable
    }

    /// A generated cover unique to this track (stable across launches), with the
    /// track number in the corner and an accent dot when the text was hand-edited.
    private var numberTile: some View {
        MiniCover(seed: "\(track.artist)|\(track.title)", size: 38, number: track.index)
            .overlay(alignment: .topTrailing) {
                if track.userEdited {
                    Circle().fill(Color.accentColor).frame(width: 9, height: 9)
                        .overlay(Circle().strokeBorder(.white.opacity(0.9), lineWidth: 1.5))
                        .offset(x: 3, y: -3)
                        .help("Edited by hand")
                        .transition(.scale)
                }
            }
            .animation(Theme.quick, value: track.userEdited)
    }
}
