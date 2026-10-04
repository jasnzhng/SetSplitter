//
//  WarningsList.swift
//  SetSplitter
//
//  The small yellow list under the preview. Non-blocking except the one
//  "couldn't parse any tracks" case, which the footer also reflects.
//

import SwiftUI
import SetSplitterCore

struct WarningsList: View {

    let warnings: [ParseWarning]

    /// Messages are collapsed to unique lines with a count, so 30 short tracks
    /// read as one line rather than 30.
    private var lines: [(message: String, count: Int, blocking: Bool)] {
        var order: [String] = []
        var counts: [String: Int] = [:]
        var blocking: [String: Bool] = [:]
        for w in warnings {
            if counts[w.message] == nil { order.append(w.message); blocking[w.message] = w.isBlocking }
            counts[w.message, default: 0] += 1
        }
        return order.map { ($0, counts[$0] ?? 1, blocking[$0] ?? false) }
    }

    var body: some View {
        if !warnings.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(lines, id: \.message) { line in
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Image(systemName: line.blocking ? "xmark.octagon.fill" : "exclamationmark.triangle.fill")
                            .foregroundStyle(line.blocking ? Color.red : Color.yellow)
                            .font(.caption)
                        Text(line.count > 1 ? "\(line.message) (×\(line.count))" : line.message)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color.yellow.opacity(0.10)))
            .transition(.opacity.combined(with: .move(edge: .bottom)))
        }
    }
}
