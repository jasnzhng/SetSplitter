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
