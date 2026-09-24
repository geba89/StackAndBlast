import SwiftUI

/// App color palette. Block colors follow the "Candy Pop" look (see CandyUI.swift).
extension Color {

    // MARK: - Block Colors

    /// Coral (#FF6A4D)
    static let blockCoral = Color(red: 1.0, green: 0.416, blue: 0.302)

    /// Blue (#2F9BFF)
    static let blockBlue = Color(red: 0.184, green: 0.608, blue: 1.0)

    /// Purple (#9B5CFF)
    static let blockPurple = Color(red: 0.608, green: 0.361, blue: 1.0)

    /// Green (#1FD18B)
    static let blockGreen = Color(red: 0.122, green: 0.82, blue: 0.545)

    /// Yellow (#FFC53D)
    static let blockYellow = Color(red: 1.0, green: 0.773, blue: 0.239)

    /// Pink (#FF5FA8)
    static let blockPink = Color(red: 1.0, green: 0.373, blue: 0.659)

    // MARK: - Background Colors

    /// Deep charcoal background (#1E272E)
    static let background = Color(red: 0.118, green: 0.153, blue: 0.180)

    /// Grid line / lighter background (#2D3436)
    static let gridLight = Color(red: 0.176, green: 0.204, blue: 0.216)

    // MARK: - Helpers

    /// Map a BlockColor enum case to its SwiftUI Color.
    static func from(_ blockColor: BlockColor) -> Color {
        switch blockColor {
        case .coral:  return .blockCoral
        case .blue:   return .blockBlue
        case .purple: return .blockPurple
        case .green:  return .blockGreen
        case .yellow: return .blockYellow
        case .pink:   return .blockPink
        }
    }
}
