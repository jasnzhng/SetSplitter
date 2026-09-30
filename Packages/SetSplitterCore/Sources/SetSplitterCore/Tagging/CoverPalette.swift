//
//  CoverPalette.swift
//  SetSplitterCore
//
//  Pulls the dominant *vivid* colours out of a cover image, so the app can tint
//  itself to match the album. ImageIO + CoreGraphics only.
//
//  Method: shrink the image to ~32 px, bucket every pixel into a 4-bit-per-channel
//  colour cube, weight buckets by how saturated they are (so a big beige sleeve
//  doesn't beat its one red accent), ignore near-black / near-white, then pick the
//  heaviest buckets that are visibly different from each other.
//

import CoreGraphics
import Foundation
import ImageIO

public struct CoverPalette: Sendable {

    public init() {}

    /// Up to `count` dominant colours, most prominent first. Empty if the image can't be decoded.
    public func extract(from imageData: Data, count: Int = 3) -> [RGBColor] {
        guard let pixels = Self.samplePixels(imageData) else { return [] }

        struct Bucket { var weight = 0.0; var r = 0.0; var g = 0.0; var b = 0.0 }
        var buckets: [Int: Bucket] = [:]
        for color in pixels {
            // Skip near-black and near-white, unless they're clearly tinted.
            if (color.luma < 0.07 || color.luma > 0.97) && color.saturation < 0.25 { continue }
            let key = Int(color.red * 15) << 8 | Int(color.green * 15) << 4 | Int(color.blue * 15)
            var bucket = buckets[key, default: Bucket()]
            let weight = 1 + 3 * color.saturation
            bucket.weight += weight
            bucket.r += color.red * weight; bucket.g += color.green * weight; bucket.b += color.blue * weight
            buckets[key] = bucket
        }

        let ranked = buckets.values.sorted { $0.weight > $1.weight }
        var chosen: [RGBColor] = []
        for bucket in ranked {
            let color = RGBColor(red: bucket.r / bucket.weight, green: bucket.g / bucket.weight, blue: bucket.b / bucket.weight)
            if chosen.allSatisfy({ $0.distance(to: color) > 0.30 }) { chosen.append(color) }
            if chosen.count == count { break }
        }
        return chosen
    }

    // MARK: Sampling

    private static func samplePixels(_ data: Data) -> [RGBColor]? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: 32,
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary),
              let space = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }

        let width = image.width, height = image.height
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        let drew = bytes.withUnsafeMutableBytes { buffer -> Bool in
            guard let ctx = CGContext(data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8,
                                      bytesPerRow: width * 4, space: space,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            ctx.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard drew else { return nil }

        return stride(from: 0, to: bytes.count, by: 4).compactMap { i in
            let alpha = Double(bytes[i + 3]) / 255
            guard alpha > 0.5 else { return nil }   // ignore transparent pixels
            // Premultiplied → straight.
            return RGBColor(red: min(1, Double(bytes[i]) / 255 / alpha),
                            green: min(1, Double(bytes[i + 1]) / 255 / alpha),
                            blue: min(1, Double(bytes[i + 2]) / 255 / alpha))
        }
    }
}
