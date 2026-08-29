//
//  SetSplitterApp.swift
//  SetSplitter
//

import SwiftUI

@main
struct SetSplitterApp: App {
    var body: some Scene {
        // Single-window wizard — `Window`, not `WindowGroup`, so ⌘N can't spawn
        // a second wizard that the shared session state can't model.
        Window("SetSplitter", id: "main") {
            ContentView()
        }
        .windowResizability(.contentSize)
    }
}
