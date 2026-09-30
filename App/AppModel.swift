//
//  AppModel.swift
//  SetSplitter
//
//  Composition root: builds the store, the production services and the three
//  view models once. Views receive view models; nothing else constructs them.
//

import AppKit
import SetSplitterCore

@MainActor
final class AppModel {

    let store: SessionStore
    let importViewModel: ImportViewModel
    let tracklistViewModel: TracklistViewModel
    let exportViewModel: ExportViewModel

    init(preferences: any PreferencesStoring = UserDefaultsPreferences()) {
        let picker = OpenPanelFilePicker()
        let store = SessionStore(preferences: preferences)

        self.store = store
        self.importViewModel = ImportViewModel(
            store: store, inspector: AVFoundationAudioInspector(), picker: picker)
        self.tracklistViewModel = TracklistViewModel(store: store)
        self.exportViewModel = ExportViewModel(
            store: store, picker: picker, preferences: preferences, job: ExportJob())
    }
}
