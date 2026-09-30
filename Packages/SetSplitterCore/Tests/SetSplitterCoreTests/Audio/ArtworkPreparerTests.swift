import CoreGraphics
import Foundation
import ImageIO
import Testing
@testable import SetSplitterCore

@Suite("ArtworkPreparer")
struct ArtworkPreparerTests {

    private func dimensions(_ jpeg: Data) -> (Int, Int)? {
        guard let s = CGImageSourceCreateWithData(jpeg as CFData, nil),
              let p = CGImageSourceCopyPropertiesAtIndex(s, 0, nil) as? [CFString: Any],
              let w = p[kCGImagePropertyPixelWidth] as? Int, let h = p[kCGImagePropertyPixelHeight] as? Int
        else { return nil }
        return (w, h)
    }

    @Test("square image passes through as JPEG with no notices")
    func square() throws {
        let r = try ArtworkPreparer().prepare(TestImages.png(width: 800, height: 800))
        #expect(r.notices.isEmpty)
        #expect(dimensions(r.jpeg)! == (800, 800))
        #expect(r.jpeg.prefix(2) == Data([0xFF, 0xD8]))
    }

    @Test("non-square is center-cropped and flagged")
    func crop() throws {
        let r = try ArtworkPreparer().prepare(TestImages.png(width: 1000, height: 600))
        #expect(dimensions(r.jpeg)! == (600, 600))
        #expect(r.notices == [.croppedToSquare])
    }

    @Test("huge images are downscaled to 1400")
    func downscale() throws {
        let r = try ArtworkPreparer().prepare(TestImages.png(width: 3000, height: 3000))
        #expect(dimensions(r.jpeg)! == (1400, 1400))
    }

    @Test("tiny images are flagged, not upscaled")
    func tiny() throws {
        let r = try ArtworkPreparer().prepare(TestImages.png(width: 200, height: 200))
        #expect(r.notices == [.lowResolution(pixels: 200)])
        #expect(dimensions(r.jpeg)! == (200, 200))
    }

    @Test("transparent PNG encodes (no alpha in JPEG)")
    func alpha() throws {
        let r = try ArtworkPreparer().prepare(TestImages.png(width: 400, height: 400, alpha: true))
        #expect(dimensions(r.jpeg)! == (400, 400))
    }

    @Test("garbage data throws")
    func garbage() {
        #expect(throws: ArtworkError.undecodable) { _ = try ArtworkPreparer().prepare(Data("nope".utf8)) }
    }
}
