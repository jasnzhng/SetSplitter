//
//  LoadedFileCard.swift
//  SetSplitter
//

import SwiftUI
import SetSplitterCore

struct LoadedFileCard: View {

    let source: SourceFile
    let onReplace: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 30))
                .foregroundStyle(Color.accentColor)
                .symbolEffect(.bounce, value: source.filename)   // fires when a file lands

            VStack(spacing: 4) {
                Text(source.filename)
                    .font(.title3.weight(.medium))
                    .lineLimit(2)
                    .truncationMode(.middle)
                    .multilineTextAlignment(.center)
                Text([source.info.codecName, source.info.bitrateKbps.map { "\($0) kbps" }]
                        .compactMap { $0 }.joined(separator: " · "))
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 24) {
                stat(TrackTiming.format(source.info.duration), "Duration")
                stat(source.info.sampleRate.truncatingRemainder(dividingBy: 1000) == 0
                        ? String(format: "%.0f kHz", source.info.sampleRate / 1000)
                        : String(format: "%.1f kHz", source.info.sampleRate / 1000), "Sample rate")
                stat(source.info.channels == 1 ? "Mono" : "Stereo", "Channels")
            }
            .padding(.top, 2)

            Button("Choose a Different File…", action: onReplace)
                .buttonStyle(.link)
                .font(.callout)
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .card(radius: 18)
        .accessibilityElement(children: .combine)
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.title3.weight(.semibold).monospacedDigit())
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
