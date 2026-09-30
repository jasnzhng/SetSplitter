//
//  CoverTextStyle.swift
//  SetSplitterCore
//
//  How the title sits on a generated cover: size, line spacing, where it is
//  aligned and whether it casts a shadow. The defaults are the "centred, tight,
//  shadowed" look.
//

import Foundation

public struct CoverTextStyle: Sendable, Equatable {

    /// Horizontal alignment of the lines *and* of the block within the cover's margins.
    public enum Alignment: String, CaseIterable, Sendable {
        case leading, center, trailing
    }

    /// Where the block sits vertically.
    public enum Position: String, CaseIterable, Sendable {
        case top, middle, bottom
    }

    public static let sizeRange = 0.5...1.6
    public static let lineSpacingRange = 0.7...1.3

    /// Multiplier on the default type size. A long title still shrinks to fit, so the top of the range
    /// only shows on short titles.
    public var size: Double
    /// Line height as a multiple of the font's natural line height.
    public var lineSpacing: Double
    public var alignment: Alignment
    public var position: Position
    public var shadow: Bool

    public init(size: Double = 1, lineSpacing: Double = 0.88, alignment: Alignment = .center,
                position: Position = .middle, shadow: Bool = true) {
        self.size = size
        self.lineSpacing = lineSpacing
        self.alignment = alignment
        self.position = position
        self.shadow = shadow
    }
}
