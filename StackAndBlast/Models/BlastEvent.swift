import Foundation

/// Describes a single blast event (one cascade level).
/// Used by the rendering layer to orchestrate blast animations in sequence.
struct BlastEvent {
    /// Indices of cleared rows (0–8).
    let clearedRows: [Int]

    /// Indices of cleared columns (0–8).
    let clearedColumns: [Int]

    /// Blocks displaced by the shockwave: block ID → displacement delta (dRow, dCol).
    let displacements: [UUID: GridPosition]

    /// Pairs of block IDs that swapped positions.
    let swapPairs: [(UUID, UUID)]

    /// The cascade level (0 = initial blast, 1 = first cascade, etc.).
    let cascadeLevel: Int

    /// Whether this was a cross-blast (row + column cleared simultaneously).
    var isCrossBlast: Bool {
        !clearedRows.isEmpty && !clearedColumns.isEmpty
    }

    /// Total number of lines cleared in this event.
    var totalLinesCleared: Int {
        clearedRows.count + clearedColumns.count
    }
}
