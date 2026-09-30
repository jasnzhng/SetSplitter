//
//  DropZoneView.swift
//  SetSplitter
//
//  The caption beneath the turntable while no file is loaded: what to do, what
//  went wrong, and the Browse button. (The drop target itself is the whole page.)
//

import SwiftUI

struct DropZoneView: View {

    let phase: ImportViewModel.Phase
    let isTargeted: Bool
    let onBrowse: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            Text(headline)
                .font(.title3.weight(.medium))
                .contentTransition(.opacity)
            if case .failed(let message) = phase {
                Text(message)
                    .font(.callout)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if case .loading = phase {
                ProgressView().controlSize(.small)
            } else {
                Button("Browse…", action: onBrowse)
                    .controlSize(.large)
            }
        }
        .animation(Theme.quick, value: isTargeted)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .contain)
    }

    private var headline: String {
        switch phase {
        case .loading(let name): "Reading “\(name)”…"
        default: isTargeted ? "Drop to load the record" : "Drop your \(SupportedAudio.displayName) here"
        }
    }
}
