import Foundation

/// A polyomino piece that the player drags onto the grid.
/// `cells` are relative offsets from the piece's origin (0,0).
struct Piece: Identifiable {
    let id: UUID
    let cells: [GridPosition]
    let color: BlockColor
    /// If set, this piece is a power-up that triggers on placement instead of placing blocks.
    let powerUp: PowerUpType?

    /// Number of cells in this piece (1–5).
    var cellCount: Int { cells.count }

    /// Whether this piece is a power-up piece.
    var isPowerUp: Bool { powerUp != nil }

    init(cells: [GridPosition], color: BlockColor, id: UUID = UUID(), powerUp: PowerUpType? = nil) {
        self.id = id
        self.cells = cells
        self.color = color
        self.powerUp = powerUp
    }

    /// Returns the absolute grid positions if the piece were placed at the given origin.
    func absolutePositions(at origin: GridPosition) -> [GridPosition] {
        cells.map { GridPosition(row: origin.row + $0.row, col: origin.col + $0.col) }
    }
}
