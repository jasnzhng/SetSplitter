import CoreGraphics
import ImageIO
import Foundation
import UniformTypeIdentifiers

// Spike-only: synthesize a square JPEG so the CoverArt path is exercised.
// Real app uses Tagging/ArtworkPreparer with a user-supplied image.
enum ArtworkStub {
    static func makeJPEG(side: Int = 1400) -> Data? {
        let cs = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(data: nil, width: side, height: side, bitsPerComponent: 8,
                                  bytesPerRow: 0, space: cs,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        let colors = [CGColor(red: 0.14, green: 0.15, blue: 0.22, alpha: 1),
                      CGColor(red: 0.55, green: 0.20, blue: 0.45, alpha: 1)] as CFArray
        if let grad = CGGradient(colorsSpace: cs, colors: colors, locations: [0, 1]) {
            ctx.drawLinearGradient(grad, start: .zero, end: CGPoint(x: side, y: side), options: [])
        }
        guard let image = ctx.makeImage() else { return nil }
        let out = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(out, UTType.jpeg.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(dest, image, [kCGImageDestinationLossyCompressionQuality: 0.9] as CFDictionary)
        guard CGImageDestinationFinalize(dest) else { return nil }
        return out as Data
    }
}
