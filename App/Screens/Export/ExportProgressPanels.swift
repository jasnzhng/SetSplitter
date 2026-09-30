//
//  ExportProgressPanels.swift
//  SetSplitter
//
//  The three non-form states of the Export screen: running, done, failed.
//

import SwiftUI
import SetSplitterCore

// MARK: - Running

struct ExportProgressPanel: View {

    let progress: ExportProgress
    let onCancel: () -> Void

    @Environment(SessionStore.self) private var store
    @State private var highlighted: UUID?

    var body: some View {
        VStack(spacing: 26) {
            VStack(spacing: 4) {
                Text(percent)
                    .font(.system(size: 64, weight: .thin).monospacedDigit())
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
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Exporting, \(percent). Track \(progress.currentTrack) of \(progress.trackCount).")
    }

    private var percent: String { "\(Int((progress.fraction * 100).rounded()))%" }

    /// The same segments the preview showed. With no tracklist there's one.
    private var strip: (durations: [Double], ids: [UUID]) {
        if store.tracks.isEmpty { return ([store.source?.info.duration ?? 1], [UUID()]) }
        return (store.durations, store.tracks.map(\.id))
    }
}

// MARK: - Done

struct ExportDonePanel: View {

    let result: ExportResult
    let onReveal: () -> Void
    let onEdit: () -> Void

    @State private var appeared = false

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64, weight: .light))
                .foregroundStyle(Color.accentColor)
                .scaleEffect(appeared ? 1 : 0.4)
                .opacity(appeared ? 1 : 0)
                .symbolEffect(.bounce, value: appeared)

            VStack(spacing: 5) {
                Text("Your album is ready")
                    .font(.system(size: 26, weight: .semibold))
                Text("\(result.files.count) \(result.files.count == 1 ? "track" : "tracks") written to")
                    .foregroundStyle(.secondary)
                Text((result.folder.path as NSString).abbreviatingWithTildeInPath)
                    .font(.callout.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: 480)
            }

            HStack(spacing: 10) {
                Button("Reveal in Finder", systemImage: "folder", action: onReveal)
                    .buttonStyle(.borderedProminent)
                Button("Back to Settings", action: onEdit)
            }
            .controlSize(.large)

            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "music.note.list").foregroundStyle(.secondary)
                Text("In Music, choose File ▸ Add to Library… and pick the folder. The tracks appear as one album and play without gaps.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .frame(maxWidth: 480)
            .card(radius: 10)
        }
        .padding(Theme.pagePadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { withAnimation(.spring(duration: 0.55, bounce: 0.4)) { appeared = true } }
    }
}

// MARK: - Failed

struct ExportFailedPanel: View {

    let message: String
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(.red)
            Text("The export didn't finish")
                .font(.system(size: 24, weight: .semibold))
            Text(message)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 440)
                .fixedSize(horizontal: false, vertical: true)
            Button("Back to Settings", action: onRetry)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
        }
        .padding(Theme.pagePadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
