//
//  PreparedArtwork.swift
//  SetSplitterCore
//

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Prepared artwork plus anything the UI should mention.
public struct PreparedArtwork: Sendable, Equatable {

    public enum Notice: Sendable, Hashable {
        /// The image wasn't square and was center-cropped.
        case croppedToSquare
        /// Shorter side under 300 px; Music will show it soft.
        case lowResolution(pixels: Int)
    }

    public var jpeg: Data
    /// Edge length of the square output, in pixels.
    public var pixelSize: Int
    public var notices: [Notice]
}
