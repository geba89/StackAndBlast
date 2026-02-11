import Foundation

/// Types of power-up blocks that spawn on the grid and trigger special effects when blasted.
enum PowerUpType: Int, CaseIterable, Codable {
    case colorBomb    // Clears all blocks of a random other color
    case rowBlast     // Clears the entire row
    case columnBlast  // Clears the entire column

    /// Unicode symbol displayed on the power-up block.
    var symbol: String {
        switch self {
        case .colorBomb:   return "\u{2605}" // ★
        case .rowBlast:    return "\u{2192}" // →
        case .columnBlast: return "\u{2193}" // ↓
        }
    }

    /// Short name for display.
    var name: String {
        switch self {
        case .colorBomb:   return "Color Bomb"
        case .rowBlast:    return "Row Blast"
        case .columnBlast: return "Column Blast"
        }
    }

    /// Player-facing description of what the power-up does.
    var description: String {
        switch self {
        case .colorBomb:   return "Clears ALL blocks of a random other color from the grid"
        case .rowBlast:    return "Clears the entire row where this block was"
        case .columnBlast: return "Clears the entire column where this block was"
        }
    }
}
