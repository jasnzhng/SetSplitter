//
//  SSSRGBColor.swift
//  SetSplitterCore
//
//  A UI-framework-free colour value (sRGB, 0…1), so Core can produce palettes
//  that the app turns into SwiftUI colours.
//

import CoreGraphics
import Foundation

/// An sRGB colour with components in `0...1`.
public struct SRGBColor: Hashable, Sendable {
    public var red: Double
    public var green: Double
    public var blue: Double

    public init(red: Double, green: Double, blue: Double) {
        self.red = red
        self.green = green
        self.blue = blue
    }

    /// Perceptual-ish brightness, 0 (black) … 1 (white).
    public var luma: Double { 0.2126 * red + 0.7152 * green + 0.0722 * blue }

    /// HSV saturation, 0 (grey) … 1 (vivid).
    public var saturation: Double {
        let maxC = max(red, green, blue), minC = min(red, green, blue)
        return maxC == 0 ? 0 : (maxC - minC) / maxC
    }

    /// Straight-line distance in RGB space (0 … √3).
    public func distance(to other: SRGBColor) -> Double {
        let dr = red - other.red, dg = green - other.green, db = blue - other.blue
        return (dr * dr + dg * dg + db * db).squareRoot()
    }

    /// Mixes toward `other` by `amount` (0 = self, 1 = other).
    public func mixed(with other: SRGBColor, _ amount: Double) -> SRGBColor {
        SRGBColor(red: red + (other.red - red) * amount,
                 green: green + (other.green - green) * amount,
                 blue: blue + (other.blue - blue) * amount)
    }

    var cgColor: CGColor {
        CGColor(red: red, green: green, blue: blue, alpha: 1)
    }
}
