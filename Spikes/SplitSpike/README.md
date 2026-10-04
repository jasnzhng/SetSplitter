# SplitSpike — Phase 0 feasibility spike

Throwaway. Proves the streaming audio split + iTunes
metadata + gapless pipeline end to end before the real architecture is built.
The real implementation ports `SampleBufferSplitting.swift`, `TrackWriter.swift`,
`MetadataBuilder.swift`, `EncodingSettings.swift` into `Packages/SetSplitterCore`.

## Run

```
swift build -c release
.build/release/split-spike <input.mp3> "0:00,0:45,1:30,2:15" [--codec aac|alac] [--bitrate 256] [--out DIR] [--album NAME] [--no-verify]
```

- Streams a decode of `input`, cuts it at the given timestamps into per-track
  `.m4a` files with full metadata + synthesized artwork.
- Then decodes the outputs back, concatenates, and compares frame counts / seams
  against the source decode (`--no-verify` to skip).
- Prints raw `ilst` atom bytes and `ffprobe` tags so metadata is checked against
  the real on-disk data, not `AVAsset.load(.metadata)`.

## Fixture

`Fixtures/short-set.mp3` — 30 s stereo sweep, 44.1 kHz, made with:

```
ffmpeg -f lavfi -i "aevalsrc=0.4*sin(2*PI*(300+220*t)*t)|0.4*sin(2*PI*(2000-30*t)*t):s=44100:d=30" -c:a libmp3lame -b:a 192k Fixtures/short-set.mp3
```
