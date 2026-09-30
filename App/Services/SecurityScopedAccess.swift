//
//  SecurityScopedAccess.swift
//  SetSplitter
//
//  implementation.md §10. RAII wrapper around start/stopAccessingSecurityScopedResource.
//  Access begins on init and ends on deinit, so holding the object for the
//  whole export (source file *and* output parent folder) is enough.
//

import Foundation

final class SecurityScopedAccess: Sendable {

    let url: URL
    private let didStart: Bool

    init(url: URL) {
        self.url = url
        // Returns false for URLs that aren't security-scoped (e.g. in tests or
        // unsandboxed builds); that's fine, there is simply nothing to release.
        self.didStart = url.startAccessingSecurityScopedResource()
    }

    deinit {
        if didStart { url.stopAccessingSecurityScopedResource() }
    }
}
