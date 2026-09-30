//
//  AppDelegate.swift
//  SetSplitter
//

import AppKit
import SetSplitterCore

/// Confirms before quitting (or closing the only window) while an export runs.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    weak var model: AppModel?

    func applicationDidFinishLaunching(_ notification: Notification) {
        #if DEBUG
        if let directory = SnapshotRunner.outputDirectory(from: CommandLine.arguments) {
            Task { await SnapshotRunner.run(into: directory) }
        }
        #endif
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let model, model.store.exportState.isRunning else { return .terminateNow }

        let alert = NSAlert()
        alert.messageText = "An export is still running."
        alert.informativeText = "Quitting now cancels it and removes the partially written files."
        alert.addButton(withTitle: "Keep Exporting")
        alert.addButton(withTitle: "Cancel Export and Quit")
        alert.alertStyle = .warning
        guard alert.runModal() == .alertSecondButtonReturn else { return .terminateCancel }

        Task {
            await model.exportViewModel.cancelAndWait()
            NSApp.reply(toApplicationShouldTerminate: true)
        }
        return .terminateLater
    }
}
