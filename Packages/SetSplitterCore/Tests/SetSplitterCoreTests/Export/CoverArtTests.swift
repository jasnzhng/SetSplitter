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

    @Test("generates a square PNG of the requested size")
    func size() throws {
        let png = try CoverArtGenerator().generate(title: "Tomorrowland", artist: "Various", trackDurations: [60, 120, 90], edge: 700)
        #expect(dimensions(png)! == (700, 700))
        #expect(png.prefix(4) == Data([0x89, 0x50, 0x4E, 0x47]))
    }

    @Test("is deterministic: same input, identical bytes; different title, different image")
    func deterministic() throws {
        let g = CoverArtGenerator()
        let a = try g.generate(title: "Set A", artist: "DJ", trackDurations: [60, 30], edge: 400)
        let b = try g.generate(title: "Set A", artist: "DJ", trackDurations: [60, 30], edge: 400)
        let c = try g.generate(title: "Set B", artist: "DJ", trackDurations: [60, 30], edge: 400)
        #expect(a == b)
        #expect(a != c)
    }

    @Test("works with no tracklist and with empty text, and the result passes through ArtworkPreparer")
    func edgeInputs() throws {
        let png = try CoverArtGenerator().generate(title: "", artist: "", trackDurations: [], edge: 400)
        let prepared = try ArtworkPreparer().prepare(png)
        #expect(prepared.pixelSize == 400)
        #expect(prepared.notices.isEmpty)
    }

    @Test("handles a very long title and a 200-track list without failing")
    func stress() throws {
        let long = String(repeating: "Extended Festival Mix ", count: 12)
        let png = try CoverArtGenerator().generate(title: long, artist: "A Very Long Artist Name & Friends", trackDurations: Array(repeating: 30, count: 200), edge: 500)
        #expect(dimensions(png)! == (500, 500))
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
        let png = try CoverArtGenerator().generate(title: "Palette", artist: "Test", trackDurations: [1, 2, 3], edge: 300)
        #expect(CoverPalette().extract(from: png).count >= 2)
    }
}
