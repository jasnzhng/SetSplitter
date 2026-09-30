//
//  DroppedFiles.swift
//  SetSplitter
//
//  Turns a drop's `NSItemProvider`s into file URLs. SwiftUI's
//  `dropDestination(for: URL.self)` didn't accept Finder file drags in the
//  sandboxed app (no target highlight, no drop), so the drop zones use
//  `onDrop(of: [.fileURL])` and load the `public.file-url` item explicitly.
//

import SwiftUI
import UniformTypeIdentifiers

extension View {

    /// Makes the view a file drop target. `isTargeted` tracks the hover; `perform`
    /// receives every dropped file URL (only local files are ever delivered).
    func fileDropTarget(
        isTargeted: Binding<Bool>,
        perform: @escaping @MainActor ([URL]) -> Void
    ) -> some View {
        onDrop(of: [UTType.fileURL], isTargeted: isTargeted) { providers in
            guard !providers.isEmpty else { return false }
            // Providers are not Sendable, so the loads are started here (synchronously, on
            // the main thread) and only the resulting URLs cross into the main-actor task.
            let collector = URLCollector(expected: providers.count) { urls in
                Task { @MainActor in perform(urls) }
            }
            for provider in providers {
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                    // Finder hands over the URL as `Data`; some sources give an NSURL directly.
                    if let data = item as? Data {
                        collector.add(URL(dataRepresentation: data, relativeTo: nil))
                    } else {
                        collector.add(item as? URL)
                    }
                }
            }
            return true
        }
    }
}

/// Gathers the URLs from concurrent `loadItem` callbacks and fires once when all have reported.
private final class URLCollector: @unchecked Sendable {   // all state is guarded by `lock`
    private let lock = NSLock()
    private var urls: [URL] = []
    private var remaining: Int
    private let finish: @Sendable ([URL]) -> Void

    init(expected: Int, finish: @escaping @Sendable ([URL]) -> Void) {
        remaining = expected
        self.finish = finish
    }

    func add(_ url: URL?) {
        let done: [URL]? = lock.withLock {
            if let url { urls.append(url) }
            remaining -= 1
            return remaining == 0 ? urls : nil
        }
        if let done { finish(done) }
    }
}
