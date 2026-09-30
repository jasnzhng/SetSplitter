import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Synthesises test images with CoreGraphics so no binary fixtures are needed.
enum TestImages {
    static func png(width: Int, height: Int, alpha: Bool = false) -> Data {
        let space = CGColorSpace(name: CGColorSpace.sRGB)!
        let ctx = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                            space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.setFillColor(CGColor(red: 0.9, green: 0.2, blue: 0.3, alpha: alpha ? 0.5 : 1))
        ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
        ctx.setFillColor(CGColor(red: 0.1, green: 0.3, blue: 0.9, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: width / 2, height: height / 2))
        let out = NSMutableData()
        let dest = CGImageDestinationCreateWithData(out, UTType.png.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(dest, ctx.makeImage()!, nil)
        CGImageDestinationFinalize(dest)
        return out as Data
    }

    /// A solid-colour PNG.
    static func png(width: Int, height: Int, color: (Double, Double, Double)) -> Data {
        split(width: width, height: height, first: color, second: color, firstFraction: 1)
    }

    /// A PNG whose left `firstFraction` of the width is `first` and the rest is `second`.
    static func split(width: Int, height: Int, first: (Double, Double, Double), second: (Double, Double, Double), firstFraction: Double) -> Data {
        let space = CGColorSpace(name: CGColorSpace.sRGB)!
        let ctx = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                            space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        let cut = Int(Double(width) * firstFraction)
        ctx.setFillColor(CGColor(red: first.0, green: first.1, blue: first.2, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: cut, height: height))
        ctx.setFillColor(CGColor(red: second.0, green: second.1, blue: second.2, alpha: 1))
        ctx.fill(CGRect(x: cut, y: 0, width: width - cut, height: height))
        let out = NSMutableData()
        let dest = CGImageDestinationCreateWithData(out, UTType.png.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(dest, ctx.makeImage()!, nil)
        CGImageDestinationFinalize(dest)
        return out as Data
    }
}
