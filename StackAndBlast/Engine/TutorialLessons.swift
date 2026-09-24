import Foundation

// MARK: - Board Sketch

/// Builds boards from little text pictures, one string per row:
///
///     ". . B B ."    '.' = empty · C coral · B blue · P purple · G green · Y yellow · K pink
///
/// Spaces are ignored, so rows can be spaced out for readability.
/// Used by the tutorial lessons below and by the unit tests.
enum BoardSketch {

    static func grid(_ rows: [String]) -> [[Block?]] {
        rows.enumerated().map { rowIndex, line in
            line.filter { $0 != " " }.enumerated().map { colIndex, symbol in
                guard let color = color(for: symbol) else { return nil }
                return Block(color: color, position: GridPosition(row: rowIndex, col: colIndex))
            }
        }
    }

    static func color(for symbol: Character) -> BlockColor? {
        switch symbol {
        case "C": return .coral
        case "B": return .blue
        case "P": return .purple
        case "G": return .green
        case "Y": return .yellow
        case "K": return .pink
        default:  return nil
        }
    }
}
