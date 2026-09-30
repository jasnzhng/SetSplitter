//
//  DropZoneView.swift
//  SetSplitter
//

import SwiftUI
import SetSplitterCore

struct DropZoneView: View {

    let phase: ImportViewModel.Phase
    let isTargeted: Bool
    let onBrowse: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            icon
            VStack(spacing: 4) {
                Text(headline)
                    .font(.title3.weight(.medium))
                if case .failed(let message) = phase {
                    Text(message)
                        .font(.callout)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text("or")
                        .font(.callout)
                        .foregroundStyle(.tertiary)
                }
            }
            if case .loading = phase {
                ProgressView().controlSize(.small)
            } else {
                Button("Browse…", action: onBrowse)
                    .controlSize(.large)
            }
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(isTargeted ? Color.accentColor.opacity(0.10) : Color(nsColor: .controlBackgroundColor).opacity(0.6))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(
                    isTargeted ? Color.accentColor : Color.secondary.opacity(0.35),
                    style: StrokeStyle(lineWidth: isTargeted ? 2 : 1.25, dash: isTargeted ? [] : [7, 5]))
        )
        .scaleEffect(isTargeted ? 1.015 : 1)
        .animation(Theme.smooth, value: isTargeted)
        .accessibilityElement(children: .contain)
    }

    private var icon: some View {
        Image(systemName: "waveform")
            .font(.system(size: 42, weight: .light))
            .foregroundStyle(isTargeted ? Color.accentColor : Color.secondary)
            .symbolEffect(.bounce, value: isTargeted)
            .frame(height: 50)
    }

    private var headline: String {
        switch phase {
        case .loading(let name): "Reading “\(name)”…"
        default: isTargeted ? "Release to import" : "Drop your \(SupportedAudio.displayName) here"
        }
    }
}
