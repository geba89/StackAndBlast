import Foundation

/// A polyomino piece that the player drags onto the grid.
/// `cells` are relative offsets from the piece's origin (0,0).
struct Piece: Identifiable {
    let id: UUID
    let cells: [GridPosition]
    let color: BlockColor

    /// Number of cells in this piece (1–5).
    var cellCount: Int { cells.count }

    init(cells: [GridPosition], color: BlockColor, id: UUID = UUID()) {
        self.id = id
        self.cells = cells
        self.color = color
    }

    /// Returns the absolute grid positions if the piece were placed at the given origin.
    func absolutePositions(at origin: GridPosition) -> [GridPosition] {
        cells.map { GridPosition(row: origin.row + $0.row, col: origin.col + $0.col) }
    }
}
