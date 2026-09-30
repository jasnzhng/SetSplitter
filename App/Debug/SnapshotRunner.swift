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
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        for (name, appearance) in [("light", NSAppearance.Name.aqua), ("dark", .darkAqua)] {
            for scenario in Scenario.allCases {
                let model = AppModel()
                model.store.parseOptions = .default
                scenario.seed(model)
                let window = makeWindow(model: model, appearance: appearance)
                await settle()
                write(window, to: directory.appendingPathComponent("\(scenario.rawValue)-\(name).png"))
                window.orderOut(nil)   // not close(): that would trip terminate-after-last-window
            }
        }
        NSApp.terminate(nil)
    }

    // MARK: Hosting

    private static func makeWindow(model: AppModel, appearance: NSAppearance.Name) -> NSWindow {
        let size = NSSize(width: 940, height: 660)
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: [.borderless], backing: .buffered, defer: false)
        window.appearance = NSAppearance(named: appearance)
        let host = NSHostingView(rootView: WizardView(model: model))
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
        if let png = rep.representation(using: .png, properties: [:]) { try? png.write(to: url) }
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

        @MainActor
        func seed(_ model: AppModel) {
            let store = model.store
            let sample = "01. [0:00](https://www.youtube.com/watch?v=x) | Belocca - Ifuna (Intro Edit) 02. [02:36](https://y.be/x&t=156s) | Dom Dolla ft. Daya - Dreamin (Eli Brown Remix) 03. [04:44](https://y.be) | John Summit ft. CLOVES - Focus (ALOK Remix) 04. [07:35](https://y.be) | A$AP Rocky - Lord Pretty Flacko Jodye 2 (LPFJ2) (HNTR Edit) 05. [10:06](https://y.be) | Vintage Culture - ID W/ | Dom Dolla - San Frandisco (Acappella) 06. [12:09](https://y.be) | Mauro Picotto & Eftihios - Like This, Like That W/ | John Summit ft. HAYLA - Where You Are (John Summit & Maddix Edit) 07. [14:57](https://y.be) | Danny Avila & Matt Sassari - Diamonds"
            if self != .importEmpty {
                let url = URL(fileURLWithPath: "/Users/dj/Music/Tomorrowland_2026_Mainstage.mp3")
                store.source = SourceFile(
                    url: url,
                    info: AudioSourceInfo(duration: 1_320, sampleRate: 44_100, channels: 2, codecName: "MP3", bitrateKbps: 320),
                    access: SecurityScopedAccess(url: url))
                store.albumTitle = "Tomorrowland 2026 Mainstage"
            }
            switch self {
            case .importEmpty, .importLoaded: break
            case .tracklistEmpty: store.step = .tracklist
            case .tracklistSample, .tracklistEdited:
                store.step = .tracklist
                store.tracklistText = sample
                store.reparse()
                if self == .tracklistEdited, let t = store.parseResult.tracks.dropFirst(2).first {
                    store.edits.setTitle("Focus (ALOK Remix) [edited]", at: t.start)
                }
            case .exportForm, .exportInvalid, .exportRunning, .exportDone, .exportFailed:
                store.step = .export
                store.tracklistText = sample
                store.reparse()
                if self != .exportInvalid {
                    store.albumArtist = "Various Artists"
                    store.artwork = SampleArtwork.make()
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

/// A synthetic cover: layered gradients, so the preview shows something realistic.
private enum SampleArtwork {
    @MainActor static func make() -> Artwork? {
        let n = 800
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let ctx = CGContext(data: nil, width: n, height: n, bitsPerComponent: 8, bytesPerRow: 0, space: space,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }
        let top = CGColor(red: 0.98, green: 0.36, blue: 0.22, alpha: 1)
        let bottom = CGColor(red: 0.16, green: 0.10, blue: 0.32, alpha: 1)
        guard let gradient = CGGradient(colorsSpace: space, colors: [top, bottom] as CFArray, locations: [0, 1]) else { return nil }
        ctx.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: n, y: n), options: [])
        ctx.setFillColor(CGColor(gray: 1, alpha: 0.9))
        for i in 0..<28 {
            let height = CGFloat(60 + (i * 47) % 300)
            let x = CGFloat(90 + i * 22)
            let y = CGFloat(n) / 2 - height / 2
            ctx.fill(CGRect(x: x, y: y, width: 12, height: height))
        }
        guard let image = ctx.makeImage() else { return nil }
        let rep = NSBitmapImageRep(cgImage: image)
        guard let png = rep.representation(using: .png, properties: [:]),
              let prepared = try? ArtworkPreparer().prepare(png) else { return nil }
        return Artwork(jpeg: prepared.jpeg, pixelSize: prepared.pixelSize, notices: prepared.notices)
    }
}
#endif
