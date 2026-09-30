//
//  ExportFailedPanel.swift
//  SetSplitter
//
//  Failure state: the typed error's user-facing message and a way back.
//

import SwiftUI

struct ExportFailedPanel: View {

    let message: String
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(.red)
                .accessibilityHidden(true)
            Text("The export didn't finish")
                .font(.display(28))
            Text(message)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 440)
                .fixedSize(horizontal: false, vertical: true)
            Button("Back to Settings", action: onRetry)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
        }
        .padding(Theme.pagePadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
