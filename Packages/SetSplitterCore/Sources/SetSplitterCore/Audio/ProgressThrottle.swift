//
//  ProgressThrottle.swift
//  SetSplitterCore
//

import Foundation

/// Rate-limits progress callbacks to ~10 Hz. Only touched from the split loop.
final class ProgressThrottle {
    private let interval: Duration
    private var last: ContinuousClock.Instant?
    init(interval: Duration) { self.interval = interval }
    func shouldEmit() -> Bool {
        let now = ContinuousClock.now
        if let last, now - last < interval { return false }
        last = now
        return true
    }
}
