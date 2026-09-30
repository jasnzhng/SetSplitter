//
//  ImportScreen.swift
//  SetSplitter
//
//  Step 1: drop or browse for the long mix; on success, confirm what was
//  read (duration, sample rate, channels) before enabling Continue.
//

import SwiftUI
import SetSplitterCore

struct ImportScreen: View {

    let model: ImportViewModel
    @Environment(SessionStore.self) private var store

    @State private var isTargeted = false

    var body: some View {
        VStack(spacing: 22) {
            VStack(spacing: 6) {
                Text("Import your set")
                    .font(.display(34))
                Text("One long \(SupportedAudio.displayName) in, a gapless album out.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }

            ZStack {
                if let source = store.source {
                    LoadedFileCard(source: source, onReplace: { withAnimation(Theme.smooth) { model.clear() } })
                        .transition(.opacity.combined(with: .scale(scale: 0.96)))
                } else {
                    DropZoneView(phase: model.phase, isTargeted: isTargeted, onBrowse: { Task { await model.browse() } })
                        .transition(.opacity.combined(with: .scale(scale: 1.03)))
                }
            }
            .frame(maxWidth: 520)
            .frame(height: 260)
            .animation(Theme.smooth, value: store.source != nil)
            .fileDropTarget(isTargeted: $isTargeted) { urls in
                Task { _ = await model.handleDrop(urls) }
            }
        }
        .padding(Theme.pagePadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Empty / dragging / loading / error states

// MARK: - Loaded state
