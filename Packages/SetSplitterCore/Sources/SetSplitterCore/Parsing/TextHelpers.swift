//
//  TextHelpers.swift
//  SetSplitterCore
//
//  Small pure helpers shared by more than one parser stage.
//

import Foundation

enum TextHelpers {

    /// `true` when every `(`/`[` has a matching closer and none closes early.
    /// Stages use it to fall back to flat scanning on malformed input rather
    /// than letting one stray bracket swallow the rest of the string.
    static func bracketsBalanced(_ chars: [Character]) -> Bool {
        var round = 0, square = 0
        for c in chars {
            switch c {
            case "(": round += 1
            case ")": round -= 1; if round < 0 { return false }
            case "[": square += 1
            case "]": square -= 1; if square < 0 { return false }
            default: break
            }
        }
        return round == 0 && square == 0
    }

    /// Drops empty strings and case-insensitive repeats, keeping the first spelling.
    static func dedupedCaseInsensitively(_ names: [String]) -> [String] {
        var seen = Set<String>()
        return names.filter { !$0.isEmpty && seen.insert($0.lowercased()).inserted }
    }
}
