import AVFoundation
import CoreMedia

//
//  SampleBufferSplitting.swift
//  SetSplitterCore
//
//  Cuts an interleaved-LPCM CMSampleBuffer at
//  an exact frame index. Ported from the Phase 0 spike: the CoreMedia range
//  API worked on every split there, the manual block-buffer path is a fallback.
//

enum SampleBufferSplitting {
    /// Splits `buffer` into `[0, headFrames)` and `[headFrames, count)`.
    /// Prefers `CMSampleBufferCopySampleBufferForRange`; falls back to manual slicing.
    static func split(_ buffer: CMSampleBuffer, headFrames: Int) throws -> SplitOutcome {
        let total = CMSampleBufferGetNumSamples(buffer)
        guard headFrames > 0, headFrames < total else { throw SampleSplitError.splitPointOutsideBuffer }

        var head: CMSampleBuffer?
        var tail: CMSampleBuffer?
        let s1 = CMSampleBufferCopySampleBufferForRange(
            allocator: kCFAllocatorDefault, sampleBuffer: buffer,
            sampleRange: CFRange(location: 0, length: headFrames), sampleBufferOut: &head)
        let s2 = CMSampleBufferCopySampleBufferForRange(
            allocator: kCFAllocatorDefault, sampleBuffer: buffer,
            sampleRange: CFRange(location: headFrames, length: total - headFrames), sampleBufferOut: &tail)

        if s1 == noErr, s2 == noErr, let h = head, let t = tail {
            return SplitOutcome(head: h, tail: t)
        }

        let manual = try manualSplit(buffer, headFrames: headFrames, totalFrames: total)
        return SplitOutcome(head: manual.0, tail: manual.1)
    }

    // MARK: Manual path

    private static func manualSplit(
        _ buffer: CMSampleBuffer, headFrames: Int, totalFrames: Int
    ) throws -> (CMSampleBuffer, CMSampleBuffer) {
        guard let formatDesc = CMSampleBufferGetFormatDescription(buffer) else {
            throw SampleSplitError.missingFormatDescription
        }
        guard let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(formatDesc)?.pointee else {
            throw SampleSplitError.missingFormatDescription
        }
        // Interleaved: one packet == one frame, mBytesPerFrame covers all channels.
        let bytesPerFrame = Int(asbd.mBytesPerFrame)
        guard bytesPerFrame > 0 else { throw SampleSplitError.notInterleavedFloat }

        guard let src = CMSampleBufferGetDataBuffer(buffer) else {
            throw SampleSplitError.missingDataBuffer
        }
        var lengthAtOffset = 0
        var totalLength = 0
        var dataPtr: UnsafeMutablePointer<Int8>?
        let acc = CMBlockBufferGetDataPointer(src, atOffset: 0, lengthAtOffsetOut: &lengthAtOffset,
                                              totalLengthOut: &totalLength, dataPointerOut: &dataPtr)
        // `lengthAtOffset` is only the contiguous run; reading `totalLength` bytes past it would be out of bounds.
        guard acc == kCMBlockBufferNoErr, let base = dataPtr, lengthAtOffset >= totalLength else {
            throw SampleSplitError.missingDataBuffer
        }

        let headBytes = headFrames * bytesPerFrame
        let tailBytes = (totalFrames - headFrames) * bytesPerFrame
        guard headBytes + tailBytes <= totalLength else { throw SampleSplitError.splitPointOutsideBuffer }

        let head = try makeBuffer(from: base, offset: 0, byteCount: headBytes,
                                  frames: headFrames, formatDesc: formatDesc, sampleRate: asbd.mSampleRate,
                                  bytesPerFrame: bytesPerFrame, template: buffer, frameOffsetInSource: 0)
        let tail = try makeBuffer(from: base, offset: headBytes, byteCount: tailBytes,
                                  frames: totalFrames - headFrames, formatDesc: formatDesc, sampleRate: asbd.mSampleRate,
                                  bytesPerFrame: bytesPerFrame, template: buffer, frameOffsetInSource: headFrames)
        return (head, tail)
    }

    private static func makeBuffer(
        from base: UnsafeMutablePointer<Int8>, offset: Int, byteCount: Int,
        frames: Int, formatDesc: CMFormatDescription, sampleRate: Float64,
        bytesPerFrame: Int, template: CMSampleBuffer, frameOffsetInSource: Int
    ) throws -> CMSampleBuffer {
        var block: CMBlockBuffer?
        let mk = CMBlockBufferCreateWithMemoryBlock(
            allocator: kCFAllocatorDefault, memoryBlock: nil, blockLength: byteCount,
            blockAllocator: kCFAllocatorDefault, customBlockSource: nil,
            offsetToData: 0, dataLength: byteCount, flags: 0, blockBufferOut: &block)
        guard mk == kCMBlockBufferNoErr, let block else {
            throw SampleSplitError.blockBufferCreateFailed(mk)
        }
        let assured = CMBlockBufferAssureBlockMemory(block)
        guard assured == kCMBlockBufferNoErr else { throw SampleSplitError.blockBufferCreateFailed(assured) }
        let copied = CMBlockBufferReplaceDataBytes(with: base + offset, blockBuffer: block,
                                                   offsetIntoDestination: 0, dataLength: byteCount)
        guard copied == kCMBlockBufferNoErr else { throw SampleSplitError.blockBufferCreateFailed(copied) }

        let basePTS = CMSampleBufferGetPresentationTimeStamp(template)
        let pts = CMTimeAdd(basePTS, CMTime(value: CMTimeValue(frameOffsetInSource), timescale: CMTimeScale(sampleRate)))
        var timing = CMSampleTimingInfo(
            duration: CMTime(value: 1, timescale: CMTimeScale(sampleRate)),
            presentationTimeStamp: pts,
            decodeTimeStamp: .invalid)
        var sampleSize = bytesPerFrame
        var out: CMSampleBuffer?
        let mkS = CMSampleBufferCreateReady(
            allocator: kCFAllocatorDefault, dataBuffer: block, formatDescription: formatDesc,
            sampleCount: frames, sampleTimingEntryCount: 1, sampleTimingArray: &timing,
            sampleSizeEntryCount: 1, sampleSizeArray: &sampleSize, sampleBufferOut: &out)
        guard mkS == noErr, let out else { throw SampleSplitError.sampleBufferCreateFailed(mkS) }
        return out
    }

    /// Rewrites a buffer's presentation timestamp so track writers can `startSession(atSourceTime: .zero)`.
    static func retimed(_ buffer: CMSampleBuffer, toStartFrame startFrame: Int, sampleRate: Double) throws -> CMSampleBuffer {
        let pts = CMTime(value: CMTimeValue(startFrame), timescale: CMTimeScale(sampleRate))
        var timing = CMSampleTimingInfo(
            duration: CMTime(value: CMTimeValue(CMSampleBufferGetNumSamples(buffer)), timescale: CMTimeScale(sampleRate)),
            presentationTimeStamp: pts,
            decodeTimeStamp: .invalid)
        var out: CMSampleBuffer?
        let s = CMSampleBufferCreateCopyWithNewTiming(
            allocator: kCFAllocatorDefault, sampleBuffer: buffer,
            sampleTimingEntryCount: 1, sampleTimingArray: &timing, sampleBufferOut: &out)
        guard s == noErr, let out else { throw SampleSplitError.retimeFailed(s) }
        return out
    }
}
