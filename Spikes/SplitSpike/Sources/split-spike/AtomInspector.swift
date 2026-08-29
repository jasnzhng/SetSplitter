import Foundation

// MARK: - Raw MP4 `ilst` walker  (implementation.md §13 Q1 & Q2)

// AVAsset.load(.metadata) round-trips AVFoundation's own in-memory model even when the on-disk
// atom is malformed, so it is NOT a real verification. This walks the actual file bytes and dumps
// the payload of each metadata `data` atom, plus the free-standing `pgap` / `cpil` atoms.

struct AtomEntry {
    let path: String      // e.g. "moov/udta/meta/ilst/trkn/data"
    let type: String      // 4cc of the leaf
    let payloadHex: String
    let payloadInts: [Int] // big-endian byte values, for eyeballing trkn
    let note: String
}

enum AtomInspector {
    static func dumpILST(url: URL) -> [AtomEntry] {
        guard let data = try? Data(contentsOf: url) else { return [] }
        var out: [AtomEntry] = []
        walk(data, start: 0, end: data.count, path: "", into: &out)
        return out
    }

    private static func be32(_ d: Data, _ i: Int) -> Int {
        Int(d[i]) << 24 | Int(d[i + 1]) << 16 | Int(d[i + 2]) << 8 | Int(d[i + 3])
    }

    private static func fourcc(_ d: Data, _ i: Int) -> String {
        String(bytes: d[i..<i + 4], encoding: .isoLatin1) ?? "????"
    }

    private static let containers: Set<String> = ["moov", "udta", "meta", "ilst", "trkn", "disk",
                                                  "covr", "cpil", "pgap", "gnre", "\u{00A9}nam",
                                                  "\u{00A9}ART", "aART", "\u{00A9}alb", "\u{00A9}day",
                                                  "\u{00A9}gen", "\u{00A9}cmt"]

    private static func walk(_ d: Data, start: Int, end: Int, path: String, into out: inout [AtomEntry]) {
        var i = start
        while i + 8 <= end {
            var size = be32(d, i)
            let type = fourcc(d, i + 4)
            var headerLen = 8
            if size == 1 {  // 64-bit size
                guard i + 16 <= end else { break }
                let hi = be32(d, i + 8), lo = be32(d, i + 12)
                size = hi << 32 | lo
                headerLen = 16
            }
            if size < headerLen || i + size > end {
                // `meta` is a FullBox: 4 bytes version/flags before children.
                if type == "meta", i + 12 <= end {
                    walk(d, start: i + 12, end: end, path: path + "meta/", into: &out)
                }
                break
            }
            let childPath = path + type + "/"
            let bodyStart = i + headerLen
            let bodyEnd = i + size

            if type == "meta" {
                walk(d, start: bodyStart + 4, end: bodyEnd, path: childPath, into: &out)
            } else if type == "data" {
                // data atom: [4 type][4 locale][payload]
                let pStart = bodyStart + 8
                if pStart <= bodyEnd {
                    let payload = d[pStart..<bodyEnd]
                    let bytes = [UInt8](payload)
                    let dataType = be32(d, bodyStart)
                    out.append(AtomEntry(
                        path: path + "data",
                        type: fourcc(d, i - 4 >= start ? i - 4 : i + 4),
                        payloadHex: bytes.map { String(format: "%02x", $0) }.joined(separator: " "),
                        payloadInts: bytes.map(Int.init),
                        note: "dataTypeCode=\(dataType) len=\(bytes.count)"))
                }
            } else if containers.contains(type) || childPath.contains("ilst/") {
                walk(d, start: bodyStart, end: bodyEnd, path: childPath, into: &out)
            }
            i += size
        }
    }
}
