# SetSplitter

A local macOS app that splits one long DJ-set MP3 into a folder of individual,
gaplessly-playable `.m4a` (AAC 256) tracks with full metadata and shared album
artwork — ready to drag into Apple Music as a single continuous album.

Three-screen wizard: **Import** (drop the MP3) → **Tracklist** (paste text, tune
parse options, preview) → **Export** (artwork, album metadata, output folder, run).

See [`implementation.md`](implementation.md) for the full spec and phased plan, and
[`CLAUDE.md`](CLAUDE.md) for conventions and the Phase 0 findings.

## Status

Phase 1 (skeleton). The wizard UI arrives in Phase 4.

## Build

Requires Xcode 16+ and [XcodeGen](https://github.com/yonaskolb/XcodeGen)
(`brew install xcodegen`).

```
make gen      # regenerate SetSplitter.xcodeproj from project.yml
make build    # build the app
make test     # run the core-package tests
make run      # build + launch the app
make clean
```

`SetSplitter.xcodeproj` is generated and git-ignored — never hand-edit it; edit
`project.yml` and run `make gen`.

## Layout

- `Packages/SetSplitterCore/` — all logic, no SwiftUI/AppKit, tested with `swift test`.
- `App/` — thin SwiftUI shell.
- `Spikes/SplitSpike/` — throwaway Phase 0 feasibility spike (see its README).
