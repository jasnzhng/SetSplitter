//
//  CoverArtGenerator.swift
//  SetSplitterCore
//
//  Makes a cover for sets that don't have one. It is a *fingerprint of the set*:
//  a gradient chosen from the album name, a sun/record motif, the tracklist drawn
//  as a strip of segments (each track's width is its length), and the title in
//  monospace. Same input → byte-identical output, so a regenerated cover never
//  "changes" on the user.
//

import CoreGraphics
import CoreText
import Foundation
import ImageIO
import UniformTypeIdentifiers

public struct CoverArtGenerator: Sendable {

    public init() {}

    /// Returns PNG data for a square cover. Feed it through `ArtworkPreparer` for the JPEG that gets embedded.
    /// - Parameters:
    ///   - trackDurations: Seconds per track; drives the segment strip. May be empty.
    public func generate(title: String, artist: String, trackDurations: [Double], edge: Int = 1400) throws -> Data {
        let e = CGFloat(edge)
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let ctx = CGContext(data: nil, width: edge, height: edge, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { throw ArtworkError.encodingFailed }

        let seed = "\(artist)|\(title)"
        let hash = StableHash.fnv1a(seed)
        let scheme = CoverScheme.scheme(forSeed: seed)
        let jitter = CGFloat(hash >> 12 & 0xFF) / 255   // 0…1, decides the motif's position

        // 1. Gradient background.
        let colors = [scheme.top.cgColor, scheme.bottom.cgColor] as CFArray
        if let gradient = CGGradient(colorsSpace: space, colors: colors, locations: [0, 1]) {
            ctx.drawLinearGradient(gradient, start: CGPoint(x: 0, y: e), end: CGPoint(x: e, y: 0),
                                   options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
        }

        // 2. Sun / record: a cream disc with fine grooves, off-centre.
        let center = CGPoint(x: e * (0.55 + 0.2 * jitter), y: e * 0.66)
        let radius = e * 0.27
        ctx.setFillColor(CGColor(red: 1, green: 0.95, blue: 0.88, alpha: 0.92))
        ctx.fillEllipse(in: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
        ctx.setStrokeColor(CGColor(red: 0, green: 0, blue: 0, alpha: 0.10))
        ctx.setLineWidth(e * 0.0016)
        var ring = radius * 0.38
        while ring < radius * 0.97 {
            ctx.strokeEllipse(in: CGRect(x: center.x - ring, y: center.y - ring, width: ring * 2, height: ring * 2))
            ring += e * 0.012
        }
        let hole = radius * 0.30
        ctx.setFillColor(scheme.bottom.mixed(with: RGBColor(red: 0, green: 0, blue: 0), 0.25).cgColor)
        ctx.fillEllipse(in: CGRect(x: center.x - hole, y: center.y - hole, width: hole * 2, height: hole * 2))

        // 3. The tracklist as a timeline strip.
        drawStrip(trackDurations, seed: hash, in: ctx, canvas: e)

        // 4. Type, bottom-left.
        drawTitleBlock(title: title, artist: artist, in: ctx, canvas: e)

        guard let image = ctx.makeImage() else { throw ArtworkError.encodingFailed }
        let out = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(out, UTType.png.identifier as CFString, 1, nil) else {
            throw ArtworkError.encodingFailed
        }
        CGImageDestinationAddImage(dest, image, nil)
        guard CGImageDestinationFinalize(dest) else { throw ArtworkError.encodingFailed }
        return out as Data
    }

    // MARK: Strip

    private func drawStrip(_ durations: [Double], seed: UInt64, in ctx: CGContext, canvas e: CGFloat) {
        // No tracklist: a plausible-looking set of segments from the seed, so the cover still has its motif.
        let lengths = durations.isEmpty
            ? (0..<7).map { i in 1.0 + Double((seed >> UInt64(i * 5)) & 0x0F) / 8 }
            : Array(durations.prefix(48)).map { max($0, 1) }
        let total = lengths.reduce(0, +)
        let margin = e * 0.07, gap = e * 0.006
        let usable = e - margin * 2 - gap * CGFloat(lengths.count - 1)
        let y = e * 0.30, height = e * 0.032
        var x = margin
        for (i, length) in lengths.enumerated() {
            let w = max(e * 0.004, usable * CGFloat(length / total))
            ctx.setFillColor(CGColor(red: 1, green: 0.95, blue: 0.88, alpha: [0.95, 0.55, 0.78, 0.40][i % 4]))
            let rect = CGRect(x: x, y: y, width: w, height: height)
            ctx.addPath(CGPath(roundedRect: rect, cornerWidth: min(height / 2, w / 2), cornerHeight: height / 2, transform: nil))
            ctx.fillPath()
            x += w + gap
        }
    }

    // MARK: Text

    private func drawTitleBlock(title: String, artist: String, in ctx: CGContext, canvas e: CGFloat) {
        let margin = e * 0.07
        let width = e - margin * 2
        var cursorY = margin   // CG origin is bottom-left; we build the block upward.

        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleanTitle.isEmpty {
            let size = cleanTitle.count > 26 ? e * 0.052 : e * 0.072
            let height = drawWrapped(cleanTitle.uppercased(), fontName: "Menlo-Bold", size: size, kern: -size * 0.02,
                                     color: CGColor(red: 1, green: 0.97, blue: 0.93, alpha: 1),
                                     rect: CGRect(x: margin, y: cursorY, width: width, height: e * 0.2), ctx: ctx)
            cursorY += height + e * 0.022
        }
        let cleanArtist = artist.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleanArtist.isEmpty {
            _ = drawWrapped(cleanArtist.uppercased(), fontName: "Menlo-Regular", size: e * 0.026, kern: e * 0.006,
                            color: CGColor(red: 1, green: 0.97, blue: 0.93, alpha: 0.78),
                            rect: CGRect(x: margin, y: cursorY, width: width, height: e * 0.08), ctx: ctx)
        }
    }

    /// Draws wrapped text with its *bottom* at `rect.minY` and returns the height it used.
    private func drawWrapped(_ text: String, fontName: String, size: CGFloat, kern: CGFloat, color: CGColor,
                             rect: CGRect, ctx: CGContext) -> CGFloat {
        let font = CTFontCreateWithName(fontName as CFString, size, nil)
        let attributes: [NSAttributedString.Key: Any] = [
            NSAttributedString.Key(kCTFontAttributeName as String): font,
            NSAttributedString.Key(kCTForegroundColorAttributeName as String): color,
            NSAttributedString.Key(kCTKernAttributeName as String): kern,
        ]
        let framesetter = CTFramesetterCreateWithAttributedString(NSAttributedString(string: text, attributes: attributes) as CFAttributedString)
        let fit = CTFramesetterSuggestFrameSizeWithConstraints(
            framesetter, CFRange(location: 0, length: 0), nil, CGSize(width: rect.width, height: rect.height), nil)
        let frameRect = CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: ceil(fit.height))
        let frame = CTFramesetterCreateFrame(framesetter, CFRange(location: 0, length: 0), CGPath(rect: frameRect, transform: nil), nil)
        CTFrameDraw(frame, ctx)
        return frameRect.height
    }
}
