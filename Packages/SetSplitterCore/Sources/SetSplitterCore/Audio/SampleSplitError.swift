//
//  SampleSplitError.swift
//  SetSplitterCore
//

import AVFoundation
import CoreMedia

enum SampleSplitError: Error, LocalizedError {
    case missingFormatDescription
    case missingDataBuffer
    case notInterleavedFloat
    case splitPointOutsideBuffer
    case blockBufferCreateFailed(OSStatus)
    case sampleBufferCreateFailed(OSStatus)
    case retimeFailed(OSStatus)

    var errorDescription: String? {
        "The decoded audio couldn't be cut at a track boundary."
    }
}
