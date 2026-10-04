//
//  DepthAwareSplitter.swift
//  SetSplitterCore
//
//  Splits a string on marker tokens, but only
//  where they sit at paren/bracket depth 0, so "(John Summit & Maddix Edit)"
//  and "[HNTR Edit]" are never cut. Unbalanced brackets degrade to a flat
//  (depth-0-everywhere) scan rather than swallowing the rest of the string.
//
//  Matching is case-insensitive. Tokens whose edge character is alphanumeric
//  require a word boundary on that side ("ft" won't match inside "Soft");
//  tokens ending in punctuation ("ft.", "feat.") don't require a right
//  boundary, so "feat.Daya" still matches.
//

import Foundation

/// Pure utility. No stored state; every call is independent.
struct DepthAwareSplitter {

    /// A separator match found at depth 0.
    struct Match {
        /// Text before the separator (not trimmed).
        let head: String
        /// The separator token exactly as it appeared in the input.
        let separator: String
        /// Text after the separator (not trimmed).
        let tail: String
        /// Which entry of the supplied `separators` array matched.
        let separatorIndex: Int
    }

    /// Finds the first depth-0 occurrence of any token in `separators`
    /// (scanning left to right; at a given position, earlier array entries win).
    /// Returns `nil` if none match.
    func firstSplit(of separators: [String], in input: String, wholeWord: Bool) -> Match? {
        let chars = Array(input)
        let flatten = !TextHelpers.bracketsBalanced(chars)
        let lowerTokens = separators.map { Array($0.lowercased()) }

        var depth = 0
        var i = 0
        while i < chars.count {
            let c = chars[i]
            if !flatten {
                if c == "(" || c == "[" {
                    depth += 1
                    i += 1
                    continue
                }
                if c == ")" || c == "]" {
                    depth = max(0, depth - 1)
                    i += 1
                    continue
                }
            }
            if depth == 0 {
                for (idx, token) in lowerTokens.enumerated() where !token.isEmpty {
                    if matches(token, in: chars, at: i, wholeWord: wholeWord) {
                        let head = String(chars[0..<i])
                        let sep = String(chars[i..<(i + token.count)])
                        let tail = String(chars[(i + token.count)...])
                        return Match(head: head, separator: sep, tail: tail, separatorIndex: idx)
                    }
                }
            }
            i += 1
        }
        return nil
    }

    /// Splits `input` on every depth-0 occurrence of any token in `separators`.
    /// Always returns at least one component. Components are not trimmed.
    func allComponents(splittingOn separators: [String], in input: String, wholeWord: Bool) -> [String] {
        let chars = Array(input)
        let flatten = !TextHelpers.bracketsBalanced(chars)
        let lowerTokens = separators.map { Array($0.lowercased()) }

        var components: [String] = []
        var current: [Character] = []
        var depth = 0
        var i = 0
        while i < chars.count {
            let c = chars[i]
            if !flatten {
                if c == "(" || c == "[" {
                    depth += 1
                    current.append(c)
                    i += 1
                    continue
                }
                if c == ")" || c == "]" {
                    depth = max(0, depth - 1)
                    current.append(c)
                    i += 1
                    continue
                }
            }
            if depth == 0 {
                var matched = false
                for token in lowerTokens where !token.isEmpty {
                    if matches(token, in: chars, at: i, wholeWord: wholeWord) {
                        components.append(String(current))
                        current.removeAll(keepingCapacity: true)
                        i += token.count
                        matched = true
                        break
                    }
                }
                if matched { continue }
            }
            current.append(c)
            i += 1
        }
        components.append(String(current))
        return components
    }

    // MARK: - Helpers

    /// Case-insensitive compare of `token` (already lowercased) against
    /// `chars[at ..< at+token.count]`, with optional word-boundary checks on
    /// alphanumeric token edges.
    private func matches(_ token: [Character], in chars: [Character], at start: Int, wholeWord: Bool) -> Bool {
        let end = start + token.count
        guard end <= chars.count else { return false }
        for k in 0..<token.count {
            if Character(chars[start + k].lowercased()) != token[k] { return false }
        }
        guard wholeWord else { return true }

        if let firstEdge = token.first, firstEdge.isLetter || firstEdge.isNumber {
            if start > 0 {
                let before = chars[start - 1]
                if before.isLetter || before.isNumber { return false }
            }
        }
        if let lastEdge = token.last, lastEdge.isLetter || lastEdge.isNumber {
            if end < chars.count {
                let after = chars[end]
                if after.isLetter || after.isNumber { return false }
            }
        }
        return true
    }
}
