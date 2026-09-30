//
//  ExportScreen.swift
//  SetSplitter
//
//  Step 3. The form (artwork + album details + destination) swaps in place for
//  the progress, done and failed panels as the export advances.
//

import SwiftUI
import SetSplitterCore

struct ExportScreen: View {

    let model: ExportViewModel
    @Environment(SessionStore.self) private var store

    var body: some View {
        ZStack {
            switch store.exportState {
            case .idle:
                ExportForm(model: model).transition(Self.swap)
            case .running(let progress):
                ExportProgressPanel(progress: progress, onCancel: model.cancel).transition(Self.swap)
            case .finished(let result):
                ExportDonePanel(result: result, cover: store.artwork?.image, palette: store.backdropPalette,
                                onReveal: model.revealInFinder, onEdit: model.editSettings)
                    .transition(Self.swap)
            case .failed(let message):
                ExportFailedPanel(message: message, onRetry: model.editSettings).transition(Self.swap)
            }
        }
        .animation(Theme.smooth, value: stateKey)
        .confirmationDialog(
            "“\(existingFolderName)” already exists",
            isPresented: Bindable(model).isAskingAboutExistingFolder,
            titleVisibility: .visible
        ) {
            Button("Replace", role: .destructive) { model.resolveExistingFolder(.replace) }
            Button("Keep Both") { model.resolveExistingFolder(.keepBoth) }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Replace moves the existing folder to the Trash. Keep Both saves this export next to it.")
        }
    }

    /// The outgoing panel fades out fast and the incoming one fades in after a
    /// beat, so the two never overlap as garbled text mid-transition.
    private static let swap = AnyTransition.asymmetric(
        insertion: .opacity.combined(with: .scale(scale: 0.98)).animation(.smooth(duration: 0.35).delay(0.12)),
        removal: .opacity.animation(.easeOut(duration: 0.12)))

    /// The folder name as it will appear on disk (sanitised), not the raw form text.
    private var existingFolderName: String {
        store.exportRequest.map { ExportJob.destination(for: $0.settings).lastPathComponent } ?? store.folderName
    }

    /// Distinguishes the four export states for animation without making
    /// `ExportProgress` updates (10×/s) retrigger the transition.
    private var stateKey: Int {
        switch store.exportState {
        case .idle: 0
        case .running: 1
        case .finished: 2
        case .failed: 3
        }
    }
}
