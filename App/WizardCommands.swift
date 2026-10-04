//
//  WizardCommands.swift
//  SetSplitter
//
//  Menu-bar commands and their shortcuts: ⌘O browse, ⌘[ back,
//  ⌘⏎ continue / export.
//

import SwiftUI

struct WizardCommands: Commands {

    let model: AppModel

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("Open Audio File…") {
                Task { await model.importViewModel.browse() }
            }
            .keyboardShortcut("o")
            .disabled(model.store.exportState.isRunning)
        }
        CommandGroup(after: .toolbar) {
            Button("Back") { WizardActions(model: model).back() }
                .keyboardShortcut("[")
                .disabled(!WizardActions(model: model).canGoBack)
            Button(WizardActions(model: model).primaryTitle) { WizardActions(model: model).primary() }
                .keyboardShortcut(.return, modifiers: .command)
                .disabled(!WizardActions(model: model).primaryEnabled)
        }
    }
}
