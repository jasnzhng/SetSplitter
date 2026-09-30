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
                ExportForm(model: model)
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            case .running(let progress):
                ExportProgressPanel(progress: progress, onCancel: model.cancel)
                    .transition(.opacity.combined(with: .scale(scale: 1.02)))
            case .finished(let result):
                ExportDonePanel(result: result, onReveal: model.revealInFinder, onEdit: model.editSettings)
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
            case .failed(let message):
                ExportFailedPanel(message: message, onRetry: model.editSettings)
                    .transition(.opacity)
            }
        }
        .animation(Theme.spring, value: stateKey)
        .confirmationDialog(
            "“\(store.folderName)” already exists",
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
