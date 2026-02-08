import Foundation

/// A position on the 9×9 game grid.
/// Origin (0,0) is top-left; row increases downward, column increases rightward.
struct GridPosition: Hashable, Codable {
    let row: Int
    let col: Int

    /// Whether this position is within the 9×9 grid bounds.
    var isValid: Bool {
        row >= 0 && row < GameConstants.gridSize &&
        col >= 0 && col < GameConstants.gridSize
    }

    /// Returns a new position offset by the given delta, wrapping around grid edges.
    func wrapped(dRow: Int, dCol: Int) -> GridPosition {
        let newRow = (row + dRow + GameConstants.gridSize) % GameConstants.gridSize
        let newCol = (col + dCol + GameConstants.gridSize) % GameConstants.gridSize
        return GridPosition(row: newRow, col: newCol)
    }
}
