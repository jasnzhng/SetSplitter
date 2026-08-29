//
//  ContentView.swift
//  SetSplitter
//

import SwiftUI

/// Placeholder shell. The three-screen wizard (Import → Tracklist → Export)
/// arrives in Phase 4; Phase 1 only needs the app to launch to a window.
struct ContentView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "waveform")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)
            Text("SetSplitter")
                .font(.title2.weight(.semibold))
            Text("Wizard coming in Phase 4")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(width: 760, height: 520)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    ContentView()
}
