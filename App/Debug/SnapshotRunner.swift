//
//  SnapshotRunner.swift
//  SetSplitter
//
//  DEBUG-only visual-verification harness. Launch with
//
//      SetSplitter.app/Contents/MacOS/SetSplitter --snapshot /some/dir
//
//  and it hosts the real `WizardView` in an offscreen window, drives it through
//  each screen state with seeded data, writes a PNG per state in light and dark,
//  then quits. This lets the UI be reviewed headlessly (no screen-recording
//  permission, no window server interaction) and exercises the production views.
//

#if DEBUG
import AppKit
import SwiftUI
import SetSplitterCore

@MainActor
enum SnapshotRunner {

    static func outputDirectory(from arguments: [String]) -> URL? {
        guard let i = arguments.firstIndex(of: "--snapshot"), i + 1 < arguments.count else { return nil }
        return URL(fileURLWithPath: arguments[i + 1], isDirectory: true)
    }

    static func run(into directory: URL) async {
        do { try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true) } catch {
            print("snapshot: can't create \(directory.path): \(error)"); NSApp.terminate(nil); return
        }
        for (name, appearance) in [("light", NSAppearance.Name.aqua), ("dark", .darkAqua)] {
            for scenario in Scenario.allCases {
                let model = AppModel(preferences: InMemoryPreferences())   // never touch the developer's real defaults
                scenario.seed(model)
                let root: AnyView
                switch scenario {
                case .turntableGallery: root = AnyView(TurntableGallery().background(LivingBackdrop(palette: .resting(for: .importFile))))
                case .finaleGallery: root = AnyView(FinaleGallery())
                default: root = AnyView(WizardView(model: model))
                }
                let window = makeWindow(root: root, appearance: appearance)
                await settle()
                write(window, to: directory.appendingPathComponent("\(scenario.rawValue)-\(name).png"))
                window.orderOut(nil)   // not close(): that would trip terminate-after-last-window
            }
        }
        NSApp.terminate(nil)
    }

    // MARK: Hosting

    private static func makeWindow(root: AnyView, appearance: NSAppearance.Name) -> NSWindow {
        let size = NSSize(width: 940, height: 660)
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: [.borderless], backing: .buffered, defer: false)
        window.appearance = NSAppearance(named: appearance)
        let host = NSHostingView(rootView: root)
        host.frame = NSRect(origin: .zero, size: size)
        window.contentView = host
        window.orderBack(nil)   // in the window server but behind everything; needed for layout & appearance
        return window
    }

    /// Lets SwiftUI lay out, run onAppear work and finish spring animations.
    private static func settle() async {
        try? await Task.sleep(for: .milliseconds(900))
    }

    private static func write(_ window: NSWindow, to url: URL) {
        guard let view = window.contentView, let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
        view.cacheDisplay(in: view.bounds, to: rep)
        guard let png = rep.representation(using: .png, properties: [:]) else { return }
        do { try png.write(to: url) } catch { print("snapshot: couldn't write \(url.lastPathComponent): \(error)") }
    }

    // MARK: Scenarios

    enum Scenario: String, CaseIterable {
        case importEmpty = "01-import-empty"
        case importLoaded = "02-import-loaded"
        case tracklistEmpty = "03-tracklist-empty"
        case tracklistSample = "04-tracklist-sample"
        case tracklistEdited = "05-tracklist-edited"
        case exportForm = "06-export-form"
        case exportInvalid = "07-export-invalid"
        case exportRunning = "08-export-running"
        case exportDone = "09-export-done"
        case exportFailed = "10-export-failed"
        case turntableGallery = "11-turntable-gallery"
        case finaleGallery = "12-finale-gallery"
        case exportFormPhoto = "13-export-form-photo"

        @MainActor
        func seed(_ model: AppModel) {
            let store = model.store
            // The implementation.md §5 sample, as it arrives from YouTube: one line, markdown links.
            let sample = [
                "01. [0:00](https://www.youtube.com/watch?v=x) | Belocca - Ifuna (Intro Edit)",
                "02. [02:36](https://y.be/x&t=156s) | Dom Dolla ft. Daya - Dreamin (Eli Brown Remix)",
                "03. [04:44](https://y.be) | John Summit ft. CLOVES - Focus (ALOK Remix)",
                "04. [07:35](https://y.be) | A$AP Rocky - Lord Pretty Flacko Jodye 2 (LPFJ2) (HNTR Edit)",
                "05. [10:06](https://y.be) | Vintage Culture - ID W/ | Dom Dolla - San Frandisco (Acappella)",
                "06. [12:09](https://y.be) | Mauro Picotto & Eftihios - Like This, Like That W/ | John Summit ft. HAYLA - Where You Are (John Summit & Maddix Edit)",
                "07. [14:57](https://y.be) | Danny Avila & Matt Sassari - Diamonds",
            ].joined(separator: " ")
            if self != .importEmpty, self != .turntableGallery, self != .finaleGallery {
                let url = URL(fileURLWithPath: "/Users/dj/Music/Tomorrowland_2026_Mainstage.mp3")
                store.source = SourceFile(
                    url: url,
                    info: AudioSourceInfo(duration: 1_320, sampleRate: 44_100, channels: 2, codecName: "MP3", bitrateKbps: 320),
                    access: SecurityScopedAccess(url: url))
                store.albumTitle = "Tomorrowland 2026 Mainstage"
            }
            switch self {
            case .importEmpty, .importLoaded, .turntableGallery, .finaleGallery: break
            case .tracklistEmpty: store.step = .tracklist
            case .tracklistSample, .tracklistEdited:
                store.step = .tracklist
                store.tracklistText = sample
                store.reparse()
                if self == .tracklistEdited, let t = store.parseResult.tracks.dropFirst(2).first {
                    store.edits.setTitle("Focus (ALOK Remix) [edited]", at: t.start)
                }
            case .exportForm, .exportFormPhoto, .exportInvalid, .exportRunning, .exportDone, .exportFailed:
                store.step = .export
                store.tracklistText = sample
                store.reparse()
                if self != .exportInvalid {
                    store.albumArtist = "Various Artists"
                    store.cover.schemeIndex = 0
                    if self == .exportFormPhoto, let photo = SampleArtwork.photo() {
                        store.cover.background = photo
                        store.cover.backgroundName = "IMG_2041.jpg"
                        store.cover.filter = .duotone
                    }
                    store.artwork = SampleArtwork.make(title: store.albumTitle, style: store.cover.style)
                    store.outputFolder = OutputFolder(url: URL(fileURLWithPath: "/Users/dj/Music"), access: nil)
                } else {
                    model.exportViewModel.markValidationShown()
                }
                switch self {
                case .exportRunning:
                    store.exportState = .running(ExportProgress(
                        framesProcessed: 30_000_000, totalFrames: 58_212_000, currentTrack: 4, trackCount: 7,
                        currentTitle: "A$AP Rocky – Lord Pretty Flacko Jodye 2 (LPFJ2) (HNTR Edit)"))
                case .exportDone:
                    let folder = URL(fileURLWithPath: "/Users/dj/Music/Various Artists - Tomorrowland 2026 Mainstage")
                    store.exportState = .finished(ExportResult(folder: folder, files: (1...7).map { folder.appendingPathComponent("\($0).m4a") }, coverURL: nil, warnings: []))
                case .exportFailed:
                    store.exportState = .failed("The disk ran out of space. Partial files were removed.")
                default: break
                }
            }
        }
    }
}

/// Every record/tonearm state in one frame, for reviewing the art without driving the app.
private struct TurntableGallery: View {
    var body: some View {
        let palette = ArtPalette.resting(for: .importFile)
        VStack(spacing: 24) {
            HStack(alignment: .top, spacing: 8) {
                labelled("idle", Turntable(state: .idle, radius: 96, palette: palette))
                labelled("targeted", Turntable(state: .targeted, radius: 96, palette: palette))
                labelled("loaded", Turntable(state: .loaded, radius: 96, palette: palette))
            }
            HStack(alignment: .top, spacing: 8) {
                labelled("export 0%", Turntable(state: .exporting(progress: 0), radius: 96, palette: palette, trackGaps: [0.2, 0.45, 0.7]))
                labelled("export 50%", Turntable(state: .exporting(progress: 0.5), radius: 96, palette: palette, trackGaps: [0.2, 0.45, 0.7]))
                labelled("export 100%", Turntable(state: .exporting(progress: 1), radius: 96, palette: palette, trackGaps: [0.2, 0.45, 0.7]))
            }
        }
        .padding(24)
        .frame(width: 940, height: 660)
    }

    private func labelled<V: View>(_ title: String, _ view: V) -> some View {
        VStack(spacing: 6) { view; Text(title).font(.caption).foregroundStyle(.secondary) }
    }
}

/// Four moments of the export finale, frozen, in one frame.
private struct FinaleGallery: View {

    /// (label, finale flags, finished?) for each frame.
    private let moments: [(String, ExportFinale, Bool)] = [
        ("working", ExportFinale(), false),
        ("cover in, arm on", ExportFinale(progressGone: true, sleeveShown: true), true),
        ("record sliding in", ExportFinale(progressGone: true, sleeveShown: true, armGone: true, recordStopped: true, recordSlide: 0.55), true),
        ("settled", .complete, true),
    ]

    var body: some View {
        VStack(spacing: 6) {
            ForEach(Array(moments.enumerated()), id: \.offset) { _, frame in
                let model = makeModel(finished: frame.2)
                ExportStage(model: model.exportViewModel, startingFinale: frame.1, alreadyFinished: false, playsFinale: false)
                    .environment(model.store)
                    .frame(width: 800, height: 390)      // the stage's natural size…
                    .scaleEffect(0.5)                    // …shown at half size…
                    .frame(width: 400, height: 155)      // …in a frame that matches it
                    .overlay(alignment: .topLeading) { Text(frame.0).font(.system(size: 9, design: .monospaced)).foregroundStyle(.secondary) }
            }
        }
        .padding(8)
        .frame(width: 940, height: 660)
        .background(LivingBackdrop(palette: .resting(for: .export)))
    }

    @MainActor
    private func makeModel(finished: Bool) -> AppModel {
        let model = AppModel(preferences: InMemoryPreferences())
        SnapshotRunner.Scenario.exportRunning.seed(model)
        if finished { SnapshotRunner.Scenario.exportDone.seed(model) }
        return model
    }
}

/// Stand-ins for a generated cover and for a user's photo, so the form shows something realistic.
private enum SampleArtwork {
    @MainActor static func make(title: String, style: CoverStyle) -> Artwork? {
        guard let png = try? CoverArtGenerator(titleFont: { NSFont.monospacedSystemFont(ofSize: $0, weight: .heavy) as CTFont }).generate(title: title, style: style),
              let prepared = try? ArtworkPreparer().prepare(png) else { return nil }
        return Artwork(prepared: prepared, palette: CoverPalette().extract(from: prepared.jpeg))
    }

    /// A busy, photo-like PNG (sky, sun, hills) for the background-photo scenario.
    static func photo() -> Data? {
        let w = 1200, h = 900
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0, space: space,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
              let sky = CGGradient(colorsSpace: space, colors: [CGColor(red: 0.98, green: 0.80, blue: 0.45, alpha: 1),
                                                                 CGColor(red: 0.25, green: 0.50, blue: 0.85, alpha: 1)] as CFArray, locations: [0, 1])
        else { return nil }
        ctx.drawLinearGradient(sky, start: CGPoint(x: 0, y: 0), end: CGPoint(x: 0, y: h), options: [])
        ctx.setFillColor(CGColor(red: 1, green: 0.97, blue: 0.85, alpha: 1))
        ctx.fillEllipse(in: CGRect(x: 760, y: 470, width: 200, height: 200))
        for (i, tone) in [(0.16, 0.22, 0.14), (0.10, 0.30, 0.18), (0.05, 0.14, 0.10)].enumerated() {
            ctx.setFillColor(CGColor(red: tone.0, green: tone.1, blue: tone.2, alpha: 1))
            ctx.fillEllipse(in: CGRect(x: -200 + i * 380, y: -420 + i * 90, width: 1100, height: 700))
        }
        guard let image = ctx.makeImage() else { return nil }
        return NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])
    }
}

/// Keeps snapshot runs from reading or overwriting the developer's saved options and folder bookmark.
@MainActor
private final class InMemoryPreferences: PreferencesStoring {
    private var options = ParseOptions.default
    private var genre: String?
    func loadParseOptions() -> ParseOptions { options }
    func saveParseOptions(_ options: ParseOptions) { self.options = options }
    func loadGenre() -> String? { genre }
    func saveGenre(_ genre: String) { self.genre = genre }
    func loadOutputFolder() -> SecurityScopedAccess? { nil }
    func saveOutputFolder(_ url: URL) {}
}
#endif
