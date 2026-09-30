//
//  ExportStage.swift
//  SetSplitter
//
//  One continuous scene for a running export *and* its finish, so the ending can be
//  choreographed instead of being a screen swap:
//
//   working   a turntable on the left; percentage, track and Cancel on the right
//   finish    1. the percentage fades away
//             2. the album cover fades in where it was, lit like a record sleeve
//             3. the tonearm fades out
//             4. the record eases out into the sleeve (a sliver stays showing)
//             5. the sleeve glides left and the "album is ready" details fade in
//
//  All positions are in one fixed-size coordinate space (record and sleeve share a
//  vertical centre; the right-hand column is used in turn by the percentage, the
//  sleeve, and the finished summary).
//

import SwiftUI
import SetSplitterCore

struct ExportStage: View {

    let model: ExportViewModel
    @Environment(SessionStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var finale: ExportFinale
    @State private var highlighted: Timestamp?

    private let playsFinale: Bool

    /// - Parameters:
    ///   - startingFinale: Starts at a specific moment of the finale (used by the snapshot harness).
    ///   - alreadyFinished: The export was already done when the screen was built, so show the end state.
    ///   - playsFinale: `false` freezes the scene at `startingFinale` instead of animating on.
    init(model: ExportViewModel, startingFinale: ExportFinale? = nil, alreadyFinished: Bool = false, playsFinale: Bool = true) {
        self.model = model
        self.playsFinale = playsFinale
        _finale = State(initialValue: startingFinale ?? (alreadyFinished ? .complete : ExportFinale()))
    }

    // MARK: Layout constants (points)

    /// Smaller than the sleeve (by ~10 pt a side), as a real record is, so it fits inside it.
    private let recordRadius: CGFloat = 124
    private var recordDiameter: CGFloat { recordRadius * 2 }
    private let sleeveSize: CGFloat = 268
    /// Left edge of the right-hand column (clear of the tonearm's reach).
    private let columnX: CGFloat = 340
    private let columnWidth: CGFloat = 400
    private var stageWidth: CGFloat { columnX + columnWidth }

    /// How much of the record still shows past the sleeve's open (left) edge when it has slid in:
    /// just a sliver, so it reads as "a record in its sleeve".
    private let pokeOut: CGFloat = 16

    /// How far the record travels: its left edge ends `pokeOut` before the sleeve's left edge.
    private var slideDistance: CGFloat { columnX - pokeOut }

    // MARK: State from the store

    private var progress: ExportProgress {
        if case .running(let p) = store.exportState { return p }
        return ExportProgress(phase: .done, framesProcessed: 1, totalFrames: 1, currentTrack: 1, trackCount: 1)
    }
    private var result: ExportResult? {
        if case .finished(let r) = store.exportState { return r }
        return nil
    }
    private var isFinished: Bool { result != nil }

    var body: some View {
        VStack(spacing: 30) {
            ZStack(alignment: .topLeading) {
                recordLayer
                sleeveLayer
                workingColumn
                if let result { summaryColumn(result) }
            }
            .frame(width: stageWidth, height: sleeveSize, alignment: .topLeading)

            timeline
        }
        .padding(Theme.pagePadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task(id: isFinished) {
            if playsFinale, isFinished, finale != .complete { await playFinale() }
        }
    }

    // MARK: Layers

    /// Record and tonearm. The arm stays put and fades; the record slides right, under the sleeve.
    private var recordLayer: some View {
        ZStack(alignment: .topLeading) {
            VinylRecord(size: recordDiameter, isSpinning: !finale.recordStopped,
                        labelColors: Array(store.backdropPalette.colors.prefix(2)), trackGaps: trackGaps)
                .offset(x: slideDistance * finale.recordSlide, y: (sleeveSize - recordDiameter) / 2)
            Tonearm(recordRadius: recordRadius, position: finale.armGone ? .rest : .playing(progress: progress.fraction))
                .offset(y: (sleeveSize - recordDiameter) / 2)
                .opacity(finale.armGone ? 0 : 1)
        }
        .offset(x: finale.settled ? -columnX : 0)
    }

    private var sleeveLayer: some View {
        RecordSleeve(cover: store.artwork?.image, size: sleeveSize)
            .offset(x: finale.settled ? 0 : columnX)
            .opacity(finale.sleeveShown ? 1 : 0)
            .scaleEffect(finale.sleeveShown ? 1 : 0.94)
            .offset(y: finale.sleeveShown ? 0 : 10)
    }

    /// Percentage, track, Cancel: everything that belongs to "working".
    private var workingColumn: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(percent)
                .font(.display(76, weight: .ultraLight).monospacedDigit())
                .contentTransition(.numericText(value: progress.fraction))
                .animation(.smooth(duration: 0.3), value: percent)
                .accessibilityHidden(true)
            HStack(spacing: 10) {
                EqualizerBars()
                Text(progress.phase == .finalizing ? "Finishing up…" : "Track \(progress.currentTrack) of \(progress.trackCount)")
                    .font(.system(size: 15, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
                    .animation(Theme.quick, value: progress.currentTrack)
            }
            .accessibilityHidden(true)
            Text(progress.currentTitle)
                .font(.callout)
                .foregroundStyle(.tertiary)
                .lineLimit(2)
                .truncationMode(.middle)
                .frame(maxWidth: 300, alignment: .leading)
                .animation(Theme.quick, value: progress.currentTitle)
                .accessibilityHidden(true)
            Button("Cancel", role: .cancel, action: model.cancel)
                .controlSize(.large)
                .glassButtonStyle()
                .keyboardShortcut(.cancelAction)
                .padding(.top, 8)
                .disabled(isFinished)
        }
        .frame(width: columnWidth, height: sleeveSize, alignment: .leading)
        .offset(x: columnX)
        .opacity(finale.progressGone ? 0 : 1)
        .blur(radius: finale.progressGone ? 6 : 0)
        .allowsHitTesting(!finale.progressGone)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Exporting, \(percent). Track \(progress.currentTrack) of \(progress.trackCount).")
    }

    private func summaryColumn(_ result: ExportResult) -> some View {
        ExportFinishedSummary(result: result, onReveal: model.revealInFinder, onEdit: model.editSettings)
            .frame(width: columnWidth, height: sleeveSize, alignment: .leading)
            .offset(x: columnX)
            .opacity(finale.settled ? 1 : 0)
            .offset(x: finale.settled ? 0 : 24)
            .allowsHitTesting(finale.settled)
    }

    private var timeline: some View {
        TimelineStrip(
            durations: strip.durations, ids: strip.ids, progress: progress.fraction,
            highlightedID: $highlighted, height: 12)
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .glassCapsule()
            .frame(maxWidth: 600)
            .opacity(finale.progressGone ? 0 : 1)
    }

    // MARK: Derived

    private var percent: String { "\(Int((progress.fraction * 100).rounded()))%" }

    /// Where each track after the first begins, as a fraction of the whole set — cut into the record as gaps.
    private var trackGaps: [Double] {
        let durations = store.durations
        let total = durations.reduce(0, +)
        guard durations.count > 1, total > 0 else { return [] }
        var running = 0.0
        return durations.dropLast().map { d in running += d; return running / total }
    }

    private var strip: (durations: [Double], ids: [Timestamp]) {
        if store.tracks.isEmpty { return ([store.source?.info.duration ?? 1], [Timestamp(seconds: 0)]) }
        return (store.durations, store.tracks.map(\.start))
    }

    // MARK: The finale

    /// Plays the closing sequence. Cancelled automatically (via `.task(id:)`) if the view goes away.
    private func playFinale() async {
        if reduceMotion {
            withAnimation(.easeInOut(duration: 0.35)) { finale = .complete }
            return
        }
        withAnimation(.easeOut(duration: 0.45)) { finale.progressGone = true }               // 1. percentage fades
        try? await Task.sleep(for: .milliseconds(300))
        withAnimation(.easeOut(duration: 0.8)) { finale.sleeveShown = true }                  // 2. cover fades in
        try? await Task.sleep(for: .milliseconds(1000))
        withAnimation(.easeInOut(duration: 0.55)) { finale.armGone = true }                   // 3. tonearm fades away
        try? await Task.sleep(for: .milliseconds(650))
        finale.recordStopped = true                                                            // spin stops, then…
        withAnimation(.easeOut(duration: 1.4)) { finale.recordSlide = 1 }                     // 4. …record slides in (ease out), sliver showing
        try? await Task.sleep(for: .milliseconds(1600))
        withAnimation(.smooth(duration: 0.95)) { finale.settled = true }                      // 5. sleeve glides left, details in
    }
}
