import Foundation
import Testing
@testable import SetSplitter

@Suite("SupportedAudio")
struct SupportedAudioTests {

    @Test("accepts mp3, m4a and wav, whatever the case",
          arguments: ["a.mp3", "a.MP3", "a.m4a", "a.M4A", "a.wav", "a.WAV", "My Set (live).wav"])
    func accepts(_ name: String) {
        #expect(SupportedAudio.accepts(URL(fileURLWithPath: "/tmp/\(name)")))
    }

    @Test("rejects other types, protected Apple audio and extensionless files",
          arguments: ["a.ogg", "a.txt", "a.png", "a.mp4", "a", "a.mp3.zip", "a.m4p", "a.m4b"])
    func rejects(_ name: String) {
        #expect(!SupportedAudio.accepts(URL(fileURLWithPath: "/tmp/\(name)")))
    }
}
