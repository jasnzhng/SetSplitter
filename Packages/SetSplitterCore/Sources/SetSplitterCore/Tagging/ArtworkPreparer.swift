//
//  ArtworkPreparer.swift
//  SetSplitterCore
//
//  implementation.md §8. Any image → a square JPEG ≤ 1400 px. ImageIO only
//  (AppKit is off-limits in Core). Decodes via the thumbnail API so a 20 MB
//  source is never fully inflated and EXIF orientation is applied.
//

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Prepared artwork plus anything the UI should mention.
public struct PreparedArtwork: Sendable, Equatable {

    public enum Notice: Sendable, Equatable {
        /// The image wasn't square and was center-cropped.
        case croppedToSquare
        /// Shorter side under 300 px; Music will show it soft.
        case lowResolution(pixels: Int)
    }

    public var jpeg: Data
    /// Edge length of the square output, in pixels.
    public var pixelSize: Int
    public var notices: [Notice]
}

public struct ArtworkPreparer: Sendable {

    public static let maxEdge = 1400
    public static let lowResolutionThreshold = 300
    public static let jpegQuality = 0.9

    public init() {}

    public func prepare(_ data: Data) throws -> PreparedArtwork {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              CGImageSourceGetCount(source) > 0 else { throw ArtworkError.undecodable }

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: 8192,   // effectively "full size"; big files still stream-decode
            kCGImageSourceShouldCacheImmediately: false,
        ]
        guard var image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            throw ArtworkError.undecodable
        }

        var notices: [PreparedArtwork.Notice] = []
        let w = image.width, h = image.height
        let side = min(w, h)
        if w != h {
            let rect = CGRect(x: (w - side) / 2, y: (h - side) / 2, width: side, height: side)
            guard let cropped = image.cropping(to: rect) else { throw ArtworkError.undecodable }
            image = cropped
            notices.append(.croppedToSquare)
        }
        if side < Self.lowResolutionThreshold {
            notices.append(.lowResolution(pixels: side))
        }

        let target = min(side, Self.maxEdge)
        let jpeg = try encode(image, edge: target)
        return PreparedArtwork(jpeg: jpeg, pixelSize: target, notices: notices)
    }

    /// Redraws into an opaque sRGB bitmap (JPEG has no alpha; a PNG with
    /// transparency would otherwise fail or turn black) at `edge`×`edge`.
    private func encode(_ image: CGImage, edge: Int) throws -> Data {
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let ctx = CGContext(
                data: nil, width: edge, height: edge, bitsPerComponent: 8, bytesPerRow: 0,
                space: space, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)
        else { throw ArtworkError.encodingFailed }
        ctx.interpolationQuality = .high
        ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: edge, height: edge))
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: edge, height: edge))
        guard let flat = ctx.makeImage() else { throw ArtworkError.encodingFailed }

        let out = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(out, UTType.jpeg.identifier as CFString, 1, nil) else {
            throw ArtworkError.encodingFailed
        }
        CGImageDestinationAddImage(dest, flat, [kCGImageDestinationLossyCompressionQuality: Self.jpegQuality] as CFDictionary)
        guard CGImageDestinationFinalize(dest) else { throw ArtworkError.encodingFailed }
        return out as Data
    }
}
