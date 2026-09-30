//
//  SetSplitterApp.swift
//  SetSplitter
//

import SwiftUI

@main
struct SetSplitterApp: App {

    @NSApplicationDelegateAdaptor private var delegate: AppDelegate
    @State private var model: AppModel

    init() {
        #if DEBUG
        _model = State(initialValue: SnapshotRunner.launchModel(from: CommandLine.arguments) ?? AppModel())
        #else
        _model = State(initialValue: AppModel())
        #endif
    }

    var body: some Scene {
        // Single-window wizard — `Window`, not `WindowGroup`, so ⌘N can't spawn
        // a second wizard that the shared session state can't model.
        Window("SetSplitter", id: "main") {
            WizardView(model: model)
                .onAppear { delegate.model = model }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)
        .defaultSize(width: 940, height: 660)
        .commands { WizardCommands(model: model) }
    }
}
