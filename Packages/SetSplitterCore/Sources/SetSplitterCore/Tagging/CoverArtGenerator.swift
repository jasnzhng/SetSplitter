//
//  CoverArtGenerator.swift
//  SetSplitterCore
//
//  Makes a cover for sets that don't have one: the album title, centred and
//  centre-aligned, in heavy monospaced capitals over either a two-colour gradient or a photo
//  the user supplies (optionally darkened / greyscaled / duotoned so the title
//  stays readable). Same input → byte-identical output, so a cover never
//  "changes" on the user.
//

import CoreGraphics
import CoreImage
import CoreImage.CIFilterBuiltins
import CoreText
import Foundation
import ImageIO
import UniformTypeIdentifiers

public struct CoverArtGenerator: Sendable {

    /// Makes the title's font at a given point size. Core can't use AppKit, so the app passes in its own
    /// monospaced system font; the default is SF Mono Heavy where installed, else Menlo Bold.
    public typealias TitleFont = @Sendable (_ size: CGFloat) -> CTFont

    private let titleFont: TitleFont

    public init(titleFont: @escaping TitleFont = CoverArtGenerator.defaultTitleFont) {
        self.titleFont = titleFont
    }

    public static let defaultTitleFont: TitleFont = { size in
        let heavy = CTFontCreateWithName("SFMono-Heavy" as CFString, size, nil)
        // CTFontCreateWithName silently substitutes an unknown name, so check what we actually got.
        return (CTFontCopyPostScriptName(heavy) as String) == "SFMono-Heavy"
            ? heavy : CTFontCreateWithName("Menlo-Bold" as CFString, size, nil)
    }

    /// Returns PNG data for a square cover. Feed it through `ArtworkPreparer` for the JPEG that gets embedded.
    /// An empty title yields just the background.
    public func generate(title: String, style: CoverStyle = CoverStyle(), edge: Int = 1400) throws -> Data {
        let e = CGFloat(edge)
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let ctx = CGContext(data: nil, width: edge, height: edge, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { throw ArtworkError.encodingFailed }

        let scheme = style.scheme
        if let photo = style.background.flatMap({ decode($0, maxPixel: edge * 2) }) {
            drawPhoto(photo, filter: style.filter, scheme: scheme, in: ctx, canvas: e, space: space)
        } else {
            drawGradient(scheme, in: ctx, canvas: e, space: space)
        }
        drawTitle(title, style: style.text, in: ctx, canvas: e)

        guard let image = ctx.makeImage() else { throw ArtworkError.encodingFailed }
        let out = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(out, UTType.png.identifier as CFString, 1, nil) else {
            throw ArtworkError.encodingFailed
        }
        CGImageDestinationAddImage(dest, image, nil)
        guard CGImageDestinationFinalize(dest) else { throw ArtworkError.encodingFailed }
        return out as Data
    }

    // MARK: Background

    private func drawGradient(_ scheme: CoverScheme, in ctx: CGContext, canvas e: CGFloat, space: CGColorSpace) {
        let colors = [scheme.top.cgColor, scheme.bottom.cgColor] as CFArray
        guard let gradient = CGGradient(colorsSpace: space, colors: colors, locations: [0, 1]) else { return }
        ctx.drawLinearGradient(gradient, start: CGPoint(x: 0, y: e), end: CGPoint(x: e, y: 0),
                               options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
    }

    private func decode(_ data: Data, maxPixel: Int) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil), CGImageSourceGetCount(source) > 0 else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,   // honour EXIF orientation
            kCGImageSourceThumbnailMaxPixelSize: maxPixel,
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }

    /// Aspect-fills `photo` into the square canvas, then applies the colour treatment.
    private func drawPhoto(_ photo: CGImage, filter: CoverStyle.Filter, scheme: CoverScheme,
                           in ctx: CGContext, canvas e: CGFloat, space: CGColorSpace) {
        let image = recolored(photo, filter: filter, scheme: scheme, space: space)
        let w = CGFloat(image.width), h = CGFloat(image.height)
        let scale = e / min(w, h)
        let drawn = CGSize(width: w * scale, height: h * scale)
        ctx.interpolationQuality = .high
        ctx.draw(image, in: CGRect(x: (e - drawn.width) / 2, y: (e - drawn.height) / 2, width: drawn.width, height: drawn.height))
        if filter == .darken {
            ctx.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 0.5))
            ctx.fill(CGRect(x: 0, y: 0, width: e, height: e))
        }
    }

    /// Greyscale and duotone are per-pixel colour maps, which Core Image does in one pass.
    private func recolored(_ image: CGImage, filter: CoverStyle.Filter, scheme: CoverScheme, space: CGColorSpace) -> CGImage {
        guard filter == .greyscale || filter == .duotone else { return image }
        let grey = CIFilter.colorControls()
        grey.inputImage = CIImage(cgImage: image)
        grey.saturation = 0
        grey.contrast = 1.08
        guard var output = grey.outputImage else { return image }

        if filter == .duotone {
            let map = CIFilter.falseColor()
            map.inputImage = output
            map.color0 = CIColor(cgColor: scheme.bottom.mixed(with: SRGBColor(red: 0, green: 0, blue: 0), 0.3).cgColor)   // shadows
            map.color1 = CIColor(cgColor: scheme.top.cgColor)                                                              // highlights
            guard let mapped = map.outputImage else { return image }
            output = mapped
        }
        let context = CIContext(options: [.workingColorSpace: space, .outputColorSpace: space])
        return context.createCGImage(output, from: CIImage(cgImage: image).extent, format: .RGBA8, colorSpace: space) ?? image
    }

    // MARK: Title

    /// A block of heavy capitals that shrinks until it fits, placed by `style`.
    private func drawTitle(_ title: String, style: CoverTextStyle, in ctx: CGContext, canvas e: CGFloat) {
        let text = title.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !text.isEmpty else { return }

        let margin = e * 0.08
        let width = e - margin * 2, maxHeight = e * 0.62
        let requested = min(max(style.size, CoverTextStyle.sizeRange.lowerBound), CoverTextStyle.sizeRange.upperBound)
        let spacing = min(max(style.lineSpacing, CoverTextStyle.lineSpacingRange.lowerBound), CoverTextStyle.lineSpacingRange.upperBound)

        var size = e * 0.085 * requested
        let minimum = e * 0.032
        var laidOut = layout(text, size: size, width: width, alignment: style.alignment, lineSpacing: spacing)
        // Shrink until the block fits *and* no single word has to be broken across lines.
        while (laidOut.height > maxHeight || laidOut.widestWord > width) && size > minimum {
            size = max(minimum, size * 0.94)
            laidOut = layout(text, size: size, width: width, alignment: style.alignment, lineSpacing: spacing)
        }

        let y: CGFloat = switch style.position {   // CG origin is bottom-left
        case .top: e - margin - laidOut.height
        case .middle: (e - laidOut.height) / 2
        case .bottom: margin
        }
        let frameRect = CGRect(x: margin, y: y, width: width, height: laidOut.height)
        let frame = CTFramesetterCreateFrame(laidOut.framesetter, CFRange(location: 0, length: 0),
                                             CGPath(rect: frameRect, transform: nil), nil)
        ctx.saveGState()
        if style.shadow {
            // A soft shadow keeps the letters legible over a busy photo.
            ctx.setShadow(offset: CGSize(width: 0, height: -e * 0.004), blur: e * 0.022,
                          color: CGColor(red: 0, green: 0, blue: 0, alpha: 0.38))
        }
        CTFrameDraw(frame, ctx)
        ctx.restoreGState()
    }

    private func layout(_ text: String, size: CGFloat, width: CGFloat, alignment: CoverTextStyle.Alignment, lineSpacing: Double)
        -> (framesetter: CTFramesetter, height: CGFloat, widestWord: CGFloat) {
        var textAlignment: CTTextAlignment = switch alignment {
        case .leading: .left
        case .center: .center
        case .trailing: .right
        }
        var lineHeight = CGFloat(lineSpacing)
        let paragraph = withUnsafePointer(to: &textAlignment) { alignmentPointer in
            withUnsafePointer(to: &lineHeight) { heightPointer in
                let settings = [
                    CTParagraphStyleSetting(spec: .alignment, valueSize: MemoryLayout<CTTextAlignment>.size, value: alignmentPointer),
                    CTParagraphStyleSetting(spec: .lineHeightMultiple, valueSize: MemoryLayout<CGFloat>.size, value: heightPointer),
                ]
                return CTParagraphStyleCreate(settings, settings.count)
            }
        }
        let attributes: [NSAttributedString.Key: Any] = [
            NSAttributedString.Key(kCTFontAttributeName as String): titleFont(size),
            NSAttributedString.Key(kCTForegroundColorAttributeName as String): CGColor(red: 1, green: 1, blue: 1, alpha: 1),
            NSAttributedString.Key(kCTParagraphStyleAttributeName as String): paragraph,
        ]
        let framesetter = CTFramesetterCreateWithAttributedString(NSAttributedString(string: text, attributes: attributes) as CFAttributedString)
        let fit = CTFramesetterSuggestFrameSizeWithConstraints(
            framesetter, CFRange(location: 0, length: 0), nil, CGSize(width: width, height: .greatestFiniteMagnitude), nil)
        let widest = text.split(whereSeparator: \.isWhitespace).map { word -> CGFloat in
            let line = CTLineCreateWithAttributedString(NSAttributedString(string: String(word), attributes: attributes) as CFAttributedString)
            return CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil))
        }.max() ?? 0
        return (framesetter, ceil(fit.height) + size * 0.1, widest)   // a little slack so descenders never clip
    }
}
