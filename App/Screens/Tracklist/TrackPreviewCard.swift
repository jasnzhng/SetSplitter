//
//  TrackPreviewCard.swift
//  SetSplitter
//
//  One track, styled like a Music app row: artwork tile with the track number,
//  bold title over secondary artist, monospaced duration on the right. Title
//  and artist edit inline.
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
        HStack(spacing: 14) {
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
        .glassSurface(cornerRadius: Theme.rowRadius, interactive: false)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.rowRadius, style: .continuous)
                .strokeBorder(Color.accentColor.opacity(isHighlighted ? 0.7 : 0), lineWidth: 1.25)
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

    /// The track number, with an accent dot when the text was hand-edited.
    private var numberTile: some View {
        Text("\(track.index)")
            .font(.system(size: 12, weight: .semibold, design: .monospaced))
            .foregroundStyle(.secondary)
            .frame(width: 24, alignment: .trailing)
            .overlay(alignment: .topTrailing) {
                if track.userEdited {
                    Circle().fill(Color.accentColor).frame(width: 7, height: 7)
                        .offset(x: 5, y: -4)
                        .help("Edited by hand")
                        .transition(.scale)
                }
            }
            .animation(Theme.quick, value: track.userEdited)
    }
}
