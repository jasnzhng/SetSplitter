//
//  StableHash.swift
//  SetSplitterCore
//

import Foundation

/// A tiny hash that is the same on every launch and every machine.
/// (`String.hashValue` is randomised per process, so it can't seed anything a
/// user should see twice — like a track's generated cover.)
public enum StableHash {

    /// 64-bit FNV-1a over the string's UTF-8 bytes.
    public static func fnv1a(_ text: String) -> UInt64 {
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in text.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x100000001b3
        }
        return hash
    }
}
