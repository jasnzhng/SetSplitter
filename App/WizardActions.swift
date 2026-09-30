//
//  WizardActions.swift
//  SetSplitter
//
//  What the footer's Back / primary buttons (and their menu-bar twins) do on
//  each step. One place, so the button and its keyboard shortcut can't drift.
//

import Foundation

@MainActor
struct WizardActions {

    let model: AppModel

    private var store: SessionStore { model.store }

    var canGoBack: Bool {
        switch store.step {
        case .importFile: false
        case .tracklist: true
        case .export: !store.exportState.isRunning
        }
    }

    func back() {
        switch store.step {
        case .importFile: break
        case .tracklist: model.tracklistViewModel.back()
        case .export: model.exportViewModel.back()
        }
    }

    var primaryTitle: String {
        switch store.step {
        case .importFile, .tracklist:
            return "Continue"
        case .export:
            if case .finished = store.exportState { return "Split Another Set" }
            return "Export"
        }
    }

    var primaryEnabled: Bool {
        switch store.step {
        case .importFile: store.source != nil
        case .tracklist: store.canLeaveTracklist
        case .export:
            switch store.exportState {
            case .idle, .failed: true   // a click with missing fields surfaces validation instead of doing nothing
            case .running: false
            case .finished: true
            }
        }
    }

    /// The footer hides the primary button while an export runs (the progress
    /// panel owns Cancel) and on the failure screen (which has its own retry).
    var showsPrimary: Bool {
        if store.step == .export {
            switch store.exportState {
            case .running, .failed: return false
            default: return true
            }
        }
        return true
    }

    func primary() {
        switch store.step {
        case .importFile: model.importViewModel.advance()
        case .tracklist: model.tracklistViewModel.advance()
        case .export:
            if case .finished = store.exportState { model.exportViewModel.startOver() } else { model.exportViewModel.export() }
        }
    }
}
