//
//  LoadedFileCard.swift
//  SetSplitter
//
//  The caption beneath the spinning record once a file is loaded: its name, the
//  facts we read from it, and a way to swap it.
//

import SwiftUI
import SetSplitterCore

struct LoadedFileCard: View {

    let source: SourceFile
    let onReplace: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            Text(source.filename)
                .font(.title3.weight(.medium))
                .lineLimit(1)
                .truncationMode(.middle)
            Text(details)
                .font(.callout)
                .foregroundStyle(.secondary)
                .monospacedDigit()
            Button("Choose a Different File…", action: onReplace)
                .buttonStyle(.link)
                .font(.callout)
                .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
    }

    /// `MP3 · 44.1 kHz · Stereo · 2:00:00`
    private var details: String {
        [source.info.summary, TrackTiming.format(source.info.duration)].joined(separator: " · ")
    }
}
