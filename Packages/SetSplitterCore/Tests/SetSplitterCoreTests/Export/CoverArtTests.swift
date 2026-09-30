import CoreGraphics
import Foundation
import ImageIO
import Testing
@testable import SetSplitterCore

@Suite("Cover art: generator and palette")
struct CoverArtTests {

    private func dimensions(_ data: Data) -> (Int, Int)? {
        guard let s = CGImageSourceCreateWithData(data as CFData, nil),
              let p = CGImageSourceCopyPropertiesAtIndex(s, 0, nil) as? [CFString: Any],
              let w = p[kCGImagePropertyPixelWidth] as? Int, let h = p[kCGImagePropertyPixelHeight] as? Int else { return nil }
        return (w, h)
    }

    // MARK: Generator

    /// Mean luma and mean colour of a PNG, sampled on a coarse grid.
    private func average(_ png: Data) -> (luma: Double, red: Double, green: Double, blue: Double) {
        let source = CGImageSourceCreateWithData(png as CFData, nil)!
        let image = CGImageSourceCreateImageAtIndex(source, 0, nil)!
        let n = 16
        let ctx = CGContext(data: nil, width: n, height: n, bitsPerComponent: 8, bytesPerRow: n * 4,
                            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.interpolationQuality = .high
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: n, height: n))
        let bytes = ctx.data!.assumingMemoryBound(to: UInt8.self)
        var r = 0.0, g = 0.0, b = 0.0
        for i in 0..<(n * n) { r += Double(bytes[i * 4]); g += Double(bytes[i * 4 + 1]); b += Double(bytes[i * 4 + 2]) }
        let count = Double(n * n) * 255
        r /= count; g /= count; b /= count
        return (0.2126 * r + 0.7152 * g + 0.0722 * b, r, g, b)
    }

    /// Fraction (0…1) of near-white pixels inside a normalised rect (origin top-left) — i.e. where the title's ink is.
    private func ink(_ png: Data, in rect: CGRect) -> Double {
        let source = CGImageSourceCreateWithData(png as CFData, nil)!
        let image = CGImageSourceCreateImageAtIndex(source, 0, nil)!
        let n = 100
        let ctx = CGContext(data: nil, width: n, height: n, bitsPerComponent: 8, bytesPerRow: n * 4,
                            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: n, height: n))
        let bytes = ctx.data!.assumingMemoryBound(to: UInt8.self)
        var white = 0, total = 0
        for row in Int(rect.minY * Double(n))..<Int(rect.maxY * Double(n)) {          // row 0 is the top of the image
            for col in Int(rect.minX * Double(n))..<Int(rect.maxX * Double(n)) {
                let i = (row * n + col) * 4
                total += 1
                if bytes[i] > 235 && bytes[i + 1] > 235 && bytes[i + 2] > 235 { white += 1 }
            }
        }
        return Double(white) / Double(total)
    }

    private let top = CGRect(x: 0, y: 0, width: 1, height: 0.33), bottom = CGRect(x: 0, y: 0.67, width: 1, height: 0.33)
    private let left = CGRect(x: 0, y: 0, width: 0.3, height: 1), right = CGRect(x: 0.7, y: 0, width: 0.3, height: 1)

    @Test("vertical position moves the title to the top, middle or bottom")
    func verticalPosition() throws {
        let g = CoverArtGenerator()
        func render(_ p: CoverTextStyle.Position) throws -> Data {
            try g.generate(title: "Top Bottom", style: CoverStyle(text: CoverTextStyle(position: p)), edge: 400)
        }
        let atTop = try render(.top), atBottom = try render(.bottom), middle = try render(.middle)
        #expect(ink(atTop, in: top) > 0.02 && ink(atTop, in: bottom) == 0)
        #expect(ink(atBottom, in: bottom) > 0.02 && ink(atBottom, in: top) == 0)
        #expect(ink(middle, in: top) == 0 && ink(middle, in: bottom) == 0)
    }

    @Test("horizontal alignment pushes short lines left or right")
    func horizontalAlignment() throws {
        let g = CoverArtGenerator()
        func render(_ a: CoverTextStyle.Alignment) throws -> Data {
            try g.generate(title: "Hi\nthere", style: CoverStyle(text: CoverTextStyle(size: 0.6, alignment: a)), edge: 400)
        }
        let l = try render(.leading), c = try render(.center), r = try render(.trailing)
        #expect(ink(l, in: left) > 0 && ink(l, in: right) == 0)
        #expect(ink(r, in: right) > 0 && ink(r, in: left) == 0)
        #expect(ink(c, in: left) == 0 && ink(c, in: right) == 0)
    }

    @Test("size scales the title, line spacing changes a multi-line block, shadow can be switched off")
    func sizeSpacingShadow() throws {
        let g = CoverArtGenerator()
        let title = "Two Words"
        func render(_ t: CoverTextStyle) throws -> Data { try g.generate(title: title, style: CoverStyle(text: t), edge: 400) }
        let whole = CGRect(x: 0, y: 0, width: 1, height: 1)
        #expect(ink(try render(CoverTextStyle(size: 1.2)), in: whole) > ink(try render(CoverTextStyle(size: 0.6)), in: whole))
        #expect(try render(CoverTextStyle(size: 1.2, lineSpacing: 0.8)) != render(CoverTextStyle(size: 1.2, lineSpacing: 1.2)))
        #expect(try render(CoverTextStyle(shadow: true)) != render(CoverTextStyle(shadow: false)))
    }

    @Test("out-of-range text settings are clamped, not fatal")
    func clamps() throws {
        let png = try CoverArtGenerator().generate(title: "X", style: CoverStyle(text: CoverTextStyle(size: 99, lineSpacing: -3)), edge: 300)
        #expect(dimensions(png)! == (300, 300))
    }

    @Test("generates a square PNG of the requested size")
    func size() throws {
        let png = try CoverArtGenerator().generate(title: "Tomorrowland", edge: 700)
        #expect(dimensions(png)! == (700, 700))
        #expect(png.prefix(4) == Data([0x89, 0x50, 0x4E, 0x47]))
    }

    @Test("is deterministic: same input, identical bytes; different title or gradient, different image")
    func deterministic() throws {
        let g = CoverArtGenerator()
        let a = try g.generate(title: "Set A", style: CoverStyle(schemeIndex: 2), edge: 400)
        let b = try g.generate(title: "Set A", style: CoverStyle(schemeIndex: 2), edge: 400)
        let c = try g.generate(title: "Set B", style: CoverStyle(schemeIndex: 2), edge: 400)
        let d = try g.generate(title: "Set A", style: CoverStyle(schemeIndex: 3), edge: 400)
        #expect(a == b)
        #expect(a != c)
        #expect(a != d)
    }

    @Test("scheme index wraps, including negatives")
    func schemeWraps() {
        let n = CoverScheme.all.count
        #expect(CoverStyle(schemeIndex: n + 1).scheme == CoverScheme.all[1])
        #expect(CoverStyle(schemeIndex: -1).scheme == CoverScheme.all[n - 1])
    }

    @Test("works with empty text, and the result passes through ArtworkPreparer")
    func edgeInputs() throws {
        let png = try CoverArtGenerator().generate(title: "", edge: 400)
        let prepared = try ArtworkPreparer().prepare(png)
        #expect(prepared.pixelSize == 400)
        #expect(prepared.notices.isEmpty)
    }

    @Test("the title is drawn: white text lightens the cover")
    func titleIsCentred() throws {
        let g = CoverArtGenerator()
        let plain = try g.generate(title: "", edge: 400)
        let titled = try g.generate(title: "Centre", edge: 400)
        #expect(plain != titled)
        #expect(average(titled).luma > average(plain).luma)
    }

    @Test("a long single word shrinks to fit rather than breaking (rendering succeeds at any word length)")
    func longWord() throws {
        let png = try CoverArtGenerator().generate(title: "Tomorrowland", edge: 400)
        #expect(dimensions(png)! == (400, 400))
        let pathological = String(repeating: "W", count: 80)
        #expect(dimensions(try CoverArtGenerator().generate(title: pathological, edge: 400))! == (400, 400))
    }

    @Test("handles a very long title without failing")
    func stress() throws {
        let long = String(repeating: "Extended Festival Mix ", count: 40)
        let png = try CoverArtGenerator().generate(title: long, edge: 500)
        #expect(dimensions(png)! == (500, 500))
    }

    // MARK: Background photo

    private let photo = TestImages.split(width: 300, height: 200, first: (0.9, 0.85, 0.2), second: (0.7, 0.9, 0.95), firstFraction: 0.5)

    @Test("a photo replaces the gradient, and a non-square photo is cropped to fill the square")
    func photoBackground() throws {
        let g = CoverArtGenerator()
        let gradient = try g.generate(title: "", edge: 300)
        let withPhoto = try g.generate(title: "", style: CoverStyle(background: photo), edge: 300)
        #expect(dimensions(withPhoto)! == (300, 300))
        #expect(gradient != withPhoto)
        let mean = average(withPhoto)
        #expect(mean.red > 0.7 && mean.green > 0.8, "bright photo colours, not the gradient's")
    }

    @Test("darken makes the photo darker; greyscale removes the colour")
    func darkenAndGreyscale() throws {
        let g = CoverArtGenerator()
        let plain = average(try g.generate(title: "", style: CoverStyle(background: photo), edge: 200))
        let dark = average(try g.generate(title: "", style: CoverStyle(background: photo, filter: .darken), edge: 200))
        let grey = average(try g.generate(title: "", style: CoverStyle(background: photo, filter: .greyscale), edge: 200))
        #expect(dark.luma < plain.luma * 0.7)
        #expect(abs(grey.red - grey.green) < 0.03 && abs(grey.green - grey.blue) < 0.03, "R≈G≈B")
    }

    @Test("duotone pulls the photo toward the gradient's colours")
    func duotone() throws {
        let g = CoverArtGenerator()
        // Scheme 0 is orange-red (top) → purple (bottom). A neutral grey photo should come out warm/violet, not grey.
        let neutral = TestImages.png(width: 200, height: 200, color: (0.6, 0.6, 0.6))
        let duo = average(try g.generate(title: "", style: CoverStyle(schemeIndex: 0, background: neutral, filter: .duotone), edge: 200))
        #expect(duo.red - duo.green > 0.05, "tinted, not neutral")
    }

    @Test("an undecodable background falls back to the gradient instead of failing")
    func badBackground() throws {
        let g = CoverArtGenerator()
        let fallback = try g.generate(title: "X", style: CoverStyle(background: Data("nope".utf8)), edge: 300)
        #expect(fallback == (try g.generate(title: "X", edge: 300)))
    }

    // MARK: Palette

    @Test("a solid red image yields red")
    func solid() {
        let colors = CoverPalette().extract(from: TestImages.png(width: 64, height: 64, color: (0.9, 0.1, 0.1)))
        #expect(colors.count == 1)
        #expect(colors[0].red > 0.8 && colors[0].green < 0.25 && colors[0].blue < 0.25)
    }

    @Test("a two-colour image yields both, most prominent first")
    func twoColours() {
        // 3/4 blue, 1/4 orange.
        let png = TestImages.split(width: 80, height: 80, first: (0.1, 0.3, 0.9), second: (1.0, 0.55, 0.1), firstFraction: 0.75)
        let colors = CoverPalette().extract(from: png)
        #expect(colors.count == 2)
        #expect(colors[0].blue > colors[0].red, "blue dominates")
        #expect(colors[1].red > colors[1].blue, "orange second")
    }

    @Test("near-black and near-white are ignored in favour of the vivid accent")
    func ignoresBlackAndWhite() {
        let png = TestImages.split(width: 80, height: 80, first: (0.02, 0.02, 0.02), second: (0.1, 0.8, 0.4), firstFraction: 0.9)
        let colors = CoverPalette().extract(from: png)
        // Resampling blends the black/green edge into a few darker greens, which may rank lower;
        // what matters is that the near-black background never wins.
        #expect(!colors.isEmpty)
        #expect(colors[0].green > 0.6, "the vivid accent leads, not the black")
        #expect(colors.allSatisfy { $0.luma > 0.07 }, "no near-black colour is returned")
    }

    @Test("garbage data yields no colours")
    func garbage() {
        #expect(CoverPalette().extract(from: Data("nope".utf8)).isEmpty)
    }

    @Test("a generated cover's palette is non-degenerate")
    func generatedPalette() throws {
        let png = try CoverArtGenerator().generate(title: "Palette", edge: 300)
        #expect(CoverPalette().extract(from: png).count >= 2)
    }
}
