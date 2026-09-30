//
//  MetadataBuilder.swift
//  SetSplitterCore
//
//  implementation.md §8, §13 Q1–Q2. Builds the iTunes-keyspace metadata items
//  for one output track. Every field here was proven writable through
//  AVAssetWriter in Phase 0 (no MP4AtomEditor fallback needed).
//

import AVFoundation

enum MetadataBuilder {

    static func items(for planned: PlannedTrack, album: AlbumMetadata, totalTracks: Int) -> [AVMetadataItem] {
        var items: [AVMetadataItem] = []
        let artist = planned.displayArtist.isEmpty ? album.albumArtist : planned.displayArtist

        items.append(string(.iTunesMetadataSongName, planned.displayTitle))
        items.append(string(.iTunesMetadataArtist, artist))
        items.append(string(.iTunesMetadataAlbum, album.album))
        items.append(string(.iTunesMetadataAlbumArtist, album.albumArtist))
        if let year = album.year { items.append(string(.iTunesMetadataReleaseDate, String(year))) }
        if let genre = album.genre, !genre.isEmpty { items.append(string(.iTunesMetadataUserGenre, genre)) }
        if let comment = album.comment, !comment.isEmpty { items.append(string(.iTunesMetadataUserComment, comment)) }

        // trkn / disk: 8-byte big-endian blob 00 00 [n:2] [total:2] 00 00.
        items.append(binary(.iTunesMetadataTrackNumber, numberPair(planned.trackNumber, of: totalTracks)))
        items.append(binary(.iTunesMetadataDiscNumber, numberPair(1, of: 1)))

        items.append(integer(.iTunesMetadataDiscCompilation, album.compilation ? 1 : 0))

        // pgap has no AVMetadataIdentifier; address it by keyspace + key and
        // write a single raw byte (an NSNumber widens to 8 bytes and reads as 0).
        if album.gaplessAlbum {
            let pgap = AVMutableMetadataItem()
            pgap.keySpace = .iTunes
            pgap.key = "pgap" as NSString
            pgap.dataType = kCMMetadataBaseDataType_UInt8 as String
            pgap.value = Data([1]) as NSData
            items.append(pgap)
        }

        if let jpeg = album.artworkJPEG {
            let art = AVMutableMetadataItem()
            art.identifier = .iTunesMetadataCoverArt
            art.dataType = kCMMetadataBaseDataType_JPEG as String
            art.value = jpeg as NSData
            items.append(art)
        }
        return items
    }

    static func numberPair(_ n: Int, of total: Int) -> Data {
        func be16(_ v: Int) -> [UInt8] { [UInt8((v >> 8) & 0xFF), UInt8(v & 0xFF)] }
        return Data([0, 0] + be16(n) + be16(total) + [0, 0])
    }

    // MARK: Item factories

    private static func string(_ id: AVMetadataIdentifier, _ value: String) -> AVMetadataItem {
        let item = AVMutableMetadataItem()
        item.identifier = id
        item.value = value as NSString
        item.extendedLanguageTag = "und"
        return item
    }

    private static func integer(_ id: AVMetadataIdentifier, _ value: Int) -> AVMetadataItem {
        let item = AVMutableMetadataItem()
        item.identifier = id
        item.value = NSNumber(value: value)
        return item
    }

    private static func binary(_ id: AVMetadataIdentifier, _ value: Data) -> AVMetadataItem {
        let item = AVMutableMetadataItem()
        item.identifier = id
        item.dataType = kCMMetadataBaseDataType_RawData as String
        item.value = value as NSData
        return item
    }
}
