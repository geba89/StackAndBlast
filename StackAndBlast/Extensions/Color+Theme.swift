import SwiftUI

/// App color palette from the GDD (section 5.1).
extension Color {

    // MARK: - Block Colors

    /// Coral (#E17055)
    static let blockCoral = Color(red: 0.882, green: 0.439, blue: 0.333)

    /// Blue (#0984E3)
    static let blockBlue = Color(red: 0.035, green: 0.518, blue: 0.890)

    /// Purple (#6C5CE7)
    static let blockPurple = Color(red: 0.424, green: 0.361, blue: 0.906)

    /// Green (#00B894)
    static let blockGreen = Color(red: 0.0, green: 0.722, blue: 0.580)

    /// Yellow (#FDCB6E)
    static let blockYellow = Color(red: 0.992, green: 0.796, blue: 0.431)

    /// Pink (#FD79A8)
    static let blockPink = Color(red: 0.992, green: 0.475, blue: 0.659)

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
