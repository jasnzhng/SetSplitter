//
//  ImportGuardTests.swift
//  SetSplitterCoreTests
//
//  implementation.md §3, §9: nothing under Sources/ may import SwiftUI or AppKit.
//  The core package must stay headlessly testable and UI-framework-free.
//

import Foundation
import Testing
@testable import SetSplitterCore

@Suite("Import guard")
struct ImportGuardTests {

    @Test("no SwiftUI or AppKit import anywhere under Sources/")
    func sourcesAreFreeOfUIFrameworks() throws {
        let sources = try Self.sourcesDirectory()
        let forbidden = ["SwiftUI", "AppKit"]

        let files = try Self.swiftFiles(under: sources)
        #expect(!files.isEmpty, "expected to find Swift files under \(sources.path)")

        var offenders: [String] = []
        for file in files {
            let text = try String(contentsOf: file, encoding: .utf8)
            for line in text.split(separator: "\n", omittingEmptySubsequences: false) {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                guard trimmed.hasPrefix("import ") else { continue }
                let module = trimmed.dropFirst("import ".count).trimmingCharacters(in: .whitespaces)
                if forbidden.contains(module) {
                    offenders.append("\(file.lastPathComponent): \(trimmed)")
                }
            }
        }
        #expect(offenders.isEmpty, "forbidden UI imports found:\n\(offenders.joined(separator: "\n"))")
    }

    // MARK: helpers

    /// Walks up from this test file to the package root (the directory holding `Package.swift`)
    /// and returns its `Sources/` directory. SwiftPM tests have no reliable working directory,
    /// so the path is derived from `#filePath`, not the CWD.
    private static func sourcesDirectory(file: StaticString = #filePath) throws -> URL {
        var dir = URL(fileURLWithPath: "\(file)").deletingLastPathComponent()
        let fm = FileManager.default
        for _ in 0..<8 {
            if fm.fileExists(atPath: dir.appendingPathComponent("Package.swift").path) {
                return dir.appendingPathComponent("Sources")
            }
            dir.deleteLastPathComponent()
        }
        throw ImportGuardError.packageRootNotFound
    }

    private static func swiftFiles(under root: URL) throws -> [URL] {
        let fm = FileManager.default
        guard let walker = fm.enumerator(at: root, includingPropertiesForKeys: nil) else { return [] }
        return walker.compactMap { $0 as? URL }.filter { $0.pathExtension == "swift" }
    }

    private enum ImportGuardError: Error { case packageRootNotFound }
}
