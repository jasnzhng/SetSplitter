import AVFoundation

// MARK: - Metadata  (implementation.md §8, §13 Q1 & Q2)

struct SpikeAlbumMetadata {
    var album: String
    var albumArtist: String
    var year: Int
    var genre: String
    var comment: String?
    var artworkJPEG: Data?
    var gaplessAlbum: Bool = true
    var compilation: Bool = false
}

struct SpikeTrack {
    var title: String
    var artist: String
    var trackNumber: Int
}

enum MetadataBuilder {
    /// Builds the iTunes-keyspace metadata items for one output track.
    static func items(for track: SpikeTrack, album: SpikeAlbumMetadata, totalTracks: Int) -> [AVMetadataItem] {
        var items: [AVMetadataItem] = []

        items.append(string(.iTunesMetadataSongName, track.title))
        items.append(string(.iTunesMetadataArtist, track.artist.isEmpty ? album.albumArtist : track.artist))
        items.append(string(.iTunesMetadataAlbum, album.album))
        items.append(string(.iTunesMetadataAlbumArtist, album.albumArtist))
        items.append(string(.iTunesMetadataReleaseDate, String(album.year)))
        items.append(string(.iTunesMetadataUserGenre, album.genre))
        if let comment = album.comment, !comment.isEmpty {
            items.append(string(.iTunesMetadataUserComment, comment))
        }

        // Track / disc number: 8-byte big-endian blob  00 00 [n] [n] [total] [total] 00 00  (§8).
        items.append(binary(.iTunesMetadataTrackNumber, trackNumberData(index: track.trackNumber, total: totalTracks)))
        items.append(binary(.iTunesMetadataDiscNumber, trackNumberData(index: 1, total: 1)))

        // Compilation flag (cpil): 1-byte int.
        items.append(integer(.iTunesMetadataDiscCompilation, album.compilation ? 1 : 0))

        // Gapless (pgap). §13 Q2: there is NO SDK identifier in AVMetadataIdentifier for it.
        // The `pgap` atom is a 1-byte boolean; address it by iTunes keyspace + key, written as
        // a single raw byte with the 8-bit-integer data type so it is not widened to 8 bytes.
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

    static func trackNumberData(index: Int, total: Int) -> Data {
        func be16(_ v: Int) -> [UInt8] { [UInt8((v >> 8) & 0xFF), UInt8(v & 0xFF)] }
        return Data([0, 0] + be16(index) + be16(total) + [0, 0])
    }

    // MARK: item factories

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
