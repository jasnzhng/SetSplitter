//
//  FilePanels.swift
//  SetSplitter
//
//  Async NSOpenPanel wrappers behind a protocol so
//  view models can be tested with a stub.
//

import AppKit
import UniformTypeIdentifiers

@MainActor
protocol FilePicking {
    func chooseAudioFile() async -> URL?
    func chooseImage() async -> URL?
    func chooseFolder(startingAt: URL?) async -> URL?
}

@MainActor
struct OpenPanelFilePicker: FilePicking {

    func chooseAudioFile() async -> URL? {
        await run { panel in
            panel.allowedContentTypes = SupportedAudio.contentTypes
            panel.message = "Choose the \(SupportedAudio.displayName) file to split."
            panel.prompt = "Choose"
        }
    }

    func chooseImage() async -> URL? {
        await run { panel in
            panel.allowedContentTypes = [.image]
            panel.message = "Choose album artwork."
            panel.prompt = "Choose"
        }
    }

    func chooseFolder(startingAt: URL?) async -> URL? {
        await run { panel in
            panel.canChooseFiles = false
            panel.canChooseDirectories = true
            panel.canCreateDirectories = true
            panel.message = "Choose where to save the album folder."
            panel.prompt = "Choose Folder"
            panel.directoryURL = startingAt ?? Self.realMusicFolder
        }
    }

    /// The user's real ~/Music. Inside the sandbox `FileManager` reports the
    /// container's fake home, but the (out-of-process) panel can open anywhere.
    static var realMusicFolder: URL {
        guard let pw = getpwuid(getuid()), let dir = pw.pointee.pw_dir else {
            return URL(fileURLWithPath: NSHomeDirectory())
        }
        return URL(fileURLWithPath: String(cString: dir)).appendingPathComponent("Music", isDirectory: true)
    }

    private func run(configure: (NSOpenPanel) -> Void) async -> URL? {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        configure(panel)
        let response = await withCheckedContinuation { continuation in
            panel.begin { continuation.resume(returning: $0) }
        }
        return response == .OK ? panel.url : nil
    }
}
