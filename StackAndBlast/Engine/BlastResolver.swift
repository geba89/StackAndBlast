import Foundation

/// Detects completed lines, executes the blast mechanic (push + swap), and returns
/// blast events for the animation layer (GDD section 3.4).
final class BlastResolver {

    /// Check the grid for completed rows/columns. If any are found, remove them,
    /// apply the shockwave push/swap, and return the blast events.
    /// Mutates the grid in place. Returns empty array if no lines were completed.
    func resolve(grid: inout [[Block?]], cascadeLevel: Int) -> [BlastEvent] {
        let completedRows = findCompletedRows(grid: grid)
        let completedCols = findCompletedColumns(grid: grid)

        guard !completedRows.isEmpty || !completedCols.isEmpty else {
            return []
        }

        // Remove blocks in completed lines
        for row in completedRows {
            for col in 0..<GameConstants.gridSize {
                grid[row][col] = nil
            }
        }
        for col in completedCols {
            for row in 0..<GameConstants.gridSize {
                grid[row][col] = nil
            }
        }

        // Apply shockwave: push adjacent rows/columns (GDD section 3.4.2)
        var displacements: [UUID: GridPosition] = [:]
        var swapPairs: [(UUID, UUID)] = []

        // Row blasts push adjacent rows laterally
        for row in completedRows {
            applyRowBlast(row: row, grid: &grid, displacements: &displacements, swapPairs: &swapPairs)
        }

        // Column blasts push adjacent columns vertically
        for col in completedCols {
            applyColumnBlast(col: col, grid: &grid, displacements: &displacements, swapPairs: &swapPairs)
        }

        let event = BlastEvent(
            clearedRows: completedRows,
            clearedColumns: completedCols,
            displacements: displacements,
            swapPairs: swapPairs,
            cascadeLevel: cascadeLevel
        )

        return [event]
    }

    // MARK: - Line Detection

    private func findCompletedRows(grid: [[Block?]]) -> [Int] {
        (0..<GameConstants.gridSize).filter { row in
            (0..<GameConstants.gridSize).allSatisfy { col in grid[row][col] != nil }
        }
    }

    private func findCompletedColumns(grid: [[Block?]]) -> [Int] {
        (0..<GameConstants.gridSize).filter { col in
            (0..<GameConstants.gridSize).allSatisfy { row in grid[row][col] != nil }
        }
    }

    // MARK: - Shockwave (GDD section 3.4.2)

    /// Row cleared → row above shifts RIGHT, row below shifts LEFT (with wrapping).
    private func applyRowBlast(
        row: Int,
        grid: inout [[Block?]],
        displacements: inout [UUID: GridPosition],
        swapPairs: inout [(UUID, UUID)]
    ) {
        // Row above shifts right
        if row > 0 {
            shiftRow(row - 1, direction: 1, grid: &grid, displacements: &displacements, swapPairs: &swapPairs)
        }
        // Row below shifts left
        if row < GameConstants.gridSize - 1 {
            shiftRow(row + 1, direction: -1, grid: &grid, displacements: &displacements, swapPairs: &swapPairs)
        }
    }

    /// Column cleared → column to left shifts DOWN, column to right shifts UP (with wrapping).
    private func applyColumnBlast(
        col: Int,
        grid: inout [[Block?]],
        displacements: inout [UUID: GridPosition],
        swapPairs: inout [(UUID, UUID)]
    ) {
        // Column to the left shifts down
        if col > 0 {
            shiftColumn(col - 1, direction: 1, grid: &grid, displacements: &displacements, swapPairs: &swapPairs)
        }
        // Column to the right shifts up
        if col < GameConstants.gridSize - 1 {
            shiftColumn(col + 1, direction: -1, grid: &grid, displacements: &displacements, swapPairs: &swapPairs)
        }
    }

    /// Shift all blocks in a row by `direction` columns (+1 = right, -1 = left) with wrapping.
    private func shiftRow(
        _ row: Int,
        direction: Int,
        grid: inout [[Block?]],
        displacements: inout [UUID: GridPosition],
        swapPairs: inout [(UUID, UUID)]
    ) {
        let size = GameConstants.gridSize
        let originalRow = grid[row]
        var newRow: [Block?] = Array(repeating: nil, count: size)

        for col in 0..<size {
            guard var block = originalRow[col] else { continue }

            // Skip blocks already displaced this blast — keep at current position
            guard displacements[block.id] == nil else {
                newRow[col] = block
                continue
            }

            let newCol = (col + direction + size) % size
            let displacement = GridPosition(row: 0, col: direction)

            if let existing = originalRow[newCol], existing.id != block.id,
               displacements[existing.id] == nil {
                // Swap: two blocks exchange positions
                swapPairs.append((block.id, existing.id))
                displacements[block.id] = displacement
                displacements[existing.id] = GridPosition(row: 0, col: -direction)

                // Move existing to this block's old position
                var swappedExisting = existing
                swappedExisting.position = GridPosition(row: row, col: col)
                newRow[col] = swappedExisting
            } else {
                displacements[block.id] = displacement
            }

            block.position = GridPosition(row: row, col: newCol)
            newRow[newCol] = block
        }

        // Replace entire row — clears old positions and writes new ones
        grid[row] = newRow
    }

    /// Shift all blocks in a column by `direction` rows (+1 = down, -1 = up) with wrapping.
    private func shiftColumn(
        _ col: Int,
        direction: Int,
        grid: inout [[Block?]],
        displacements: inout [UUID: GridPosition],
        swapPairs: inout [(UUID, UUID)]
    ) {
        let size = GameConstants.gridSize
        // Snapshot the column before mutation
        let originalCol: [Block?] = (0..<size).map { grid[$0][col] }
        var newCol: [Block?] = Array(repeating: nil, count: size)

        for row in 0..<size {
            guard var block = originalCol[row] else { continue }

            // Skip blocks already displaced this blast — keep at current position
            guard displacements[block.id] == nil else {
                newCol[row] = block
                continue
            }

            let newRow = (row + direction + size) % size
            let displacement = GridPosition(row: direction, col: 0)

            if let existing = originalCol[newRow], existing.id != block.id,
               displacements[existing.id] == nil {
                // Swap: two blocks exchange positions
                swapPairs.append((block.id, existing.id))
                displacements[block.id] = displacement
                displacements[existing.id] = GridPosition(row: -direction, col: 0)

                // Move existing to this block's old position
                var swappedExisting = existing
                swappedExisting.position = GridPosition(row: row, col: col)
                newCol[row] = swappedExisting
            } else {
                displacements[block.id] = displacement
            }

            block.position = GridPosition(row: newRow, col: col)
            newCol[newRow] = block
        }

        // Replace entire column — clears old positions and writes new ones
        for row in 0..<size {
            grid[row][col] = newCol[row]
        }
    }
}
