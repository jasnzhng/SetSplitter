//
//  ImportScreen.swift
//  SetSplitter
//
//  Step 1: drop or browse for the long mix. The screen is a turntable: dragging
//  a file over it drops the tonearm; once the file is read the record spins.
//

import SwiftUI
import SetSplitterCore

struct ImportScreen: View {

    let model: ImportViewModel
    @Environment(SessionStore.self) private var store

    @State private var isTargeted = false

    var body: some View {
        VStack(spacing: 14) {
            VStack(spacing: 6) {
                Text("Import your set")
                    .font(.display(36))
                Text("Select an \(SupportedAudio.displayName) file to split into a gapless album.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }

            Turntable(state: turntableState, radius: 118, palette: .resting(for: .importFile))
                .padding(.vertical, 4)

            ZStack {
                if let source = store.source {
                    LoadedFileCard(source: source, onReplace: { model.clear() })
                        .transition(.opacity.combined(with: .offset(y: 8)))
                } else {
                    DropZoneView(phase: model.phase, isTargeted: isTargeted, onBrowse: { Task { await model.browse() } })
                        .transition(.opacity.combined(with: .offset(y: 8)))
                }
            }
            .frame(maxWidth: 520)
            .frame(height: 120)
            .animation(Theme.smooth, value: store.source != nil)
        }
        .padding(Theme.pagePadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .fileDropTarget(isTargeted: $isTargeted) { urls in
            Task { _ = await model.handleDrop(urls) }
        }
    }

    private var turntableState: Turntable.State {
        if store.source != nil { return .loaded }
        if case .loading = model.phase { return .loading }
        return isTargeted ? .targeted : .idle
    }
}
