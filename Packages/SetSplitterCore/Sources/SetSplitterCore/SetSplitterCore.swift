//
//  SetSplitterCore.swift
//  SetSplitterCore
//

/// Marker for the SetSplitter core package.
///
/// All parsing, audio, tagging and export logic lives here and is tested headlessly
/// with `swift test`. Nothing under `Sources/` may `import SwiftUI` or `import AppKit`
/// (enforced by `ImportGuardTests`). Real types land in Phase 2 onward.
public enum SetSplitterCore {
    /// Semantic version of the core package, surfaced for diagnostics.
    public static let version = "0.1.0"
}
