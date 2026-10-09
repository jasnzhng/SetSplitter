# SetSplitter

A super simple, local macOS app that splits one long recording (MP3, M4A or WAV) into a folder of individual, gaplessly-playable `.m4a` (AAC 256) tracks with full metadata and album artwork, ready to import into Apple Music or your music app of choice. 

1. Drag in your set
2. Paste in a setlist- the app automatically picks up on timestamps and delimiters between song and artist name
4. Use the app to make album art or drop in your own
5. Export your set as a nicely formatted album! 

I built this as a weekend project for myself since I love listening to live music, updates to come!

## Roadmap + features to come
- Currently you're only able to adjust the timestamps via editing the setlist text, currently working on a more fleshed out editor that allows you to preview splits between tracks and adjust using a timeline
- Improvements to the artwork creator- more fonts, better positioning, ability to add a festival logo, more templates (akin to the Apple Music playlist cover maker)
- Automatic import into Apple Music
- Better integration and optimization with iCloud Library Sync and iTunes Match, so songs after import have richer data
- Integration with 1001Tracklists to automatically search for and grab tracklists
- Saving sets to a library in the app so users can go back and make edits

## Tech Stack
- Swift 6, targeting macOS 26
- SwiftUI for the UI, with Observation (@Observable) for state
- AppKit for the open panel and drag-and-drop
- AVFoundation (AVAssetReader / AVAssetWriter) to decode the source and encode AAC .m4a tracks with iTunes metadata
- CoreMedia for sample-buffer splitting, and AudioToolbox for audio format handling
- ImageIO, CoreGraphics, Core Image and Core Text for artwork
- UniformTypeIdentifiers for file type handling
- [XcodeGen](https://github.com/yonaskolb/xcodegen) and Swift Package Manager for the build


# Privacy Policy

**Last updated: October 8, 2026**

SetSplitter is a macOS app developed by Jason Zhang that splits one long audio recording into individual tracks. This policy explains what the app does and doesn't do with your information.

*TL;DR: SetSplitter doesn't collect, transmit, or share any of your data. Everything happens locally on your device.*

### What we collect

No information is collected. SetSplitter has no accounts, analytics, advertising, crash reporting, or tracking of any kind. I recieve no information about you or how you use the app. The app also never connects to the internet. It contains no networking code nor does it request network permissions from macOS.

### How the app uses your files and content

SetSplitter only works with and accesses files you explicitly give to the app, and only on your device:

- **Audio files.** When you drag in or open an MP3, M4A, or WAV file, the app reads it to split it into tracks. The original file is not modified.
- **Tracklists.** The setlist text you type or paste is parsed on-device to find timestamps, titles, and artists.
- **Clipboard.** The app reads your clipboard only when you click the paste button, and only to fill in the tracklist. It never reads the clipboard in the background.
- **Artwork.** Images you drop in, and cover art you design in the app, are processed on-device.
- **Exported files.** The finished `.m4a` tracks are written to the folder you choose. The track titles, artists, album name, genre, and artwork you enter are embedded in those files as metadata.

### What is stored on your device

SetSplitter saves a few small preferences so they're there the next time you use it:

- your last-used tracklist parsing options,
- the last genre you entered, and
- a bookmark to the last folder you selected for export.

These preferences stay on your Mac. They contain no account information and are never sent anywhere. The app doesn't keep copies of your audio files, tracklists, or artwork.

### Removing your data

To clear the saved preferences, quit the app and delete its container folder:

```
~/Library/Containers/com.jasonzhang.SetSplitter
```

Deleting the app itself doesn't automatically remove that folder, and it never removes the tracks you exported, which are files that belong to you.

### Third parties

SetSplitter includes no third-party SDKs, analytics, or advertising services, and shares no data with anyone.

If you share app diagnostics with me through macOS, Apple's TestFlight, or App Store tools, Apple handles that data under [Apple's privacy policy](https://www.apple.com/legal/privacy/). I don't control that and only see what Apple chooses to pass along.

### Changes to this policy

If this policy changes, I'll update the "Last updated" date above. If the app ever adds features that handle data differently (for example, online tracklist lookup), this policy will be updated accordingly (I currently have no plans to add any kind of analytics or marketing).

### Contact

Questions about this policy? Contact me at [jasonzha@umich.edu](mailto:jasonzha@umich.edu).