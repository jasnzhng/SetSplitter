# SetSplitter

A local macOS app that splits one long DJ-set MP3 into a folder of individual,
gaplessly-playable `.m4a` (AAC 256) tracks with full metadata and shared album
artwork — ready to drag into Apple Music as a single continuous album.

Three-screen wizard: **Import** (drop the MP3) → **Tracklist** (paste text, tune
parse options, preview and hand-fix tracks) → **Export** (artwork, album metadata,
output folder, run).

## Using it

1. **Import** — drop an MP3 on the window (or `⌘O`). The app reads its duration,
   sample rate and channels to confirm it's a valid file.
2. **Tracklist** — paste the tracklist in any layout (even one long line); the only
   requirement is timestamps like `0:00` or `1:02:03`. Cards preview each track live.
   Click a title or artist to fix it by hand; edits survive re-parsing. Options
   control artist/title order, separators, mashup handling and the audio before the
   first timestamp.
3. **Export** — add cover art (optional), fill in **Album** and **Album Artist**
   (required — the album artist is what makes Music group the tracks), pick a
   folder, and export. Then in Music: **File ▸ Add to Library…** and choose the
   folder. The tracks appear as one album and play without gaps.

Shortcuts: `⌘O` open file · `⌘[` back · `⌘↩` continue / export.

## Build

Requires Xcode 16+ and [XcodeGen](https://github.com/yonaskolb/XcodeGen)
(`brew install xcodegen`).

```
make gen           # regenerate SetSplitter.xcodeproj from project.yml
make build         # build the app (unsigned; CI-style)
make build-signed  # ad-hoc signed build — the App Sandbox is really on
make run           # build-signed + launch
make test          # run the core-package tests
make snapshots     # render every screen state to PNGs (light + dark), headlessly
make clean
```

`SetSplitter.xcodeproj` is generated and git-ignored — never hand-edit it; edit
`project.yml` and run `make gen`.

Long-file performance check (opt-in, needs a 2 h MP3):

```
SETSPLITTER_LONG_FILE=/path/to/two-hour.mp3 swift test -c release --filter LongSet
```

## Layout

- `Packages/SetSplitterCore/` — all logic (parser, audio splitting, tagging, export
  planning), no SwiftUI/AppKit, tested headlessly with `swift test`.
- `App/` — thin SwiftUI shell: `Navigation/` (session store), `Screens/`,
  `Components/`, `Services/`, `Design/`, `Debug/` (DEBUG-only snapshot harness).
- `Tools/make-icon.swift` — regenerates the app icon (`swift Tools/make-icon.swift …`).
- `Spikes/SplitSpike/` — throwaway Phase 0 feasibility spike (see its README).

See [`implementation.md`](implementation.md) for the spec, [`CLAUDE.md`](CLAUDE.md)
for conventions and settled decisions, and [`progress.md`](progress.md) for history.
