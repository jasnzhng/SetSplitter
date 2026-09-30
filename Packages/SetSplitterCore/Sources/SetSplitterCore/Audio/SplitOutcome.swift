//
//  SplitOutcome.swift
//  SetSplitterCore
//

import AVFoundation
import CoreMedia

/// The two halves of a buffer cut at a frame index.
struct SplitOutcome {
    let head: CMSampleBuffer
    let tail: CMSampleBuffer
}
