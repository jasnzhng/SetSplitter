//
//  ImportScreen.swift
//  SetSplitter
//
//  Step 1: drop or browse for the long mix; on success, confirm what was
//  read (duration, sample rate, channels) before enabling Continue.
//

import SwiftUI
import SetSplitterCore

struct ImportScreen: View {

    let model: ImportViewModel
    @Environment(SessionStore.self) private var store

    @State private var isTargeted = false

    var body: some View {
        VStack(spacing: 22) {
            VStack(spacing: 6) {
                Text("Import your set")
                    .font(.system(size: 26, weight: .semibold))
                Text("One long \(SupportedAudio.displayName) in, a gapless album out.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }

            ZStack {
                if let source = store.source {
                    LoadedFileCard(source: source, onReplace: { withAnimation(Theme.spring) { model.clear() } })
                        .transition(.opacity.combined(with: .scale(scale: 0.96)))
                } else {
                    DropZoneView(phase: model.phase, isTargeted: isTargeted, onBrowse: { Task { await model.browse() } })
                        .transition(.opacity.combined(with: .scale(scale: 1.03)))
                }
            }
            .frame(maxWidth: 520)
            .frame(height: 260)
            .animation(Theme.spring, value: store.source != nil)
            .dropDestination(for: URL.self) { urls, _ in
                Task { _ = await model.handleDrop(urls) }
                return true
            } isTargeted: { isTargeted = $0 }
        }
        .padding(Theme.pagePadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Empty / dragging / loading / error states

struct DropZoneView: View {

    let phase: ImportViewModel.Phase
    let isTargeted: Bool
    let onBrowse: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            icon
            VStack(spacing: 4) {
                Text(headline)
                    .font(.title3.weight(.medium))
                if case .failed(let message) = phase {
                    Text(message)
                        .font(.callout)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text("or")
                        .font(.callout)
                        .foregroundStyle(.tertiary)
                }
            }
            if case .loading = phase {
                ProgressView().controlSize(.small)
            } else {
                Button("Browse…", action: onBrowse)
                    .controlSize(.large)
            }
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(isTargeted ? Color.accentColor.opacity(0.10) : Color(nsColor: .controlBackgroundColor).opacity(0.6))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(
                    isTargeted ? Color.accentColor : Color.secondary.opacity(0.35),
                    style: StrokeStyle(lineWidth: isTargeted ? 2 : 1.25, dash: isTargeted ? [] : [7, 5]))
        )
        .scaleEffect(isTargeted ? 1.015 : 1)
        .animation(Theme.spring, value: isTargeted)
        .accessibilityElement(children: .contain)
    }

    private var icon: some View {
        Image(systemName: "waveform")
            .font(.system(size: 42, weight: .light))
            .foregroundStyle(isTargeted ? Color.accentColor : Color.secondary)
            .symbolEffect(.bounce, value: isTargeted)
            .frame(height: 50)
    }

    private var headline: String {
        switch phase {
        case .loading(let name): "Reading “\(name)”…"
        default: isTargeted ? "Release to import" : "Drop your \(SupportedAudio.displayName) here"
        }
    }
}

// MARK: - Loaded state

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
                Text(source.info.summary)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 24) {
                stat(TrackTiming.format(source.info.duration), "Duration")
                stat(source.info.bitrateKbps.map { "\($0) kbps" } ?? "—", "Bitrate")
                stat(String(format: "%.1f kHz", source.info.sampleRate / 1000), "Sample rate")
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
