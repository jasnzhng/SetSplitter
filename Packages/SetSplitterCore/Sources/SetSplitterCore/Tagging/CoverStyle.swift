//
//  CoverStyle.swift
//  SetSplitterCore
//
//  The knobs of a generated cover apart from its title: which gradient, an
//  optional photo to use instead of the gradient, the colour treatment that keeps
//  the title readable over that photo, and how the title itself is set.
//

import Foundation

public struct CoverStyle: Sendable, Equatable {

    /// A colour treatment applied to the background photo. Ignored when there is no photo.
    public enum Filter: String, CaseIterable, Sendable {
        /// The photo as it is.
        case none
        /// A black wash over the photo.
        case darken
        /// Black and white.
        case greyscale
        /// Shadows take the gradient's dark colour, highlights its light one.
        case duotone
    }

    /// Index into `CoverScheme.all` (wrapped, so any integer is valid).
    public var schemeIndex: Int
    /// Image bytes (any format ImageIO reads) drawn in place of the gradient, aspect-filled and centre-cropped.
    public var background: Data?
    public var filter: Filter
    public var text: CoverTextStyle

    public init(schemeIndex: Int = 0, background: Data? = nil, filter: Filter = .none, text: CoverTextStyle = CoverTextStyle()) {
        self.schemeIndex = schemeIndex
        self.background = background
        self.filter = filter
        self.text = text
    }

    public var scheme: CoverScheme {
        let all = CoverScheme.all
        return all[((schemeIndex % all.count) + all.count) % all.count]
    }
}
