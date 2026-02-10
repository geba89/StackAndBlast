import Foundation

/// Detects connected color groups (4+ orthogonally adjacent blocks of the same color)
/// and clears them from the grid, returning blast events for animation.
final class BlastResolver {

    /// Orthogonal neighbor offsets: up, down, left, right.
    private static let directions = [
        (row: -1, col: 0), // up
        (row: 1, col: 0),  // down
        (row: 0, col: -1), // left
        (row: 0, col: 1)   // right
    ]

    /// Scan the grid for connected color groups of 4+ blocks.
    /// Clears qualifying groups and returns blast events for each group.
    /// Mutates the grid in place. Returns empty array if no groups qualify.
    func resolve(grid: inout [[Block?]], cascadeLevel: Int) -> [BlastEvent] {
        var visited = Set<GridPosition>()
        var events: [BlastEvent] = []

        for row in 0..<GameConstants.gridSize {
            for col in 0..<GameConstants.gridSize {
                let pos = GridPosition(row: row, col: col)
                guard !visited.contains(pos),
                      let block = grid[row][col] else { continue }

                // Flood-fill to find all connected blocks of the same color
                let group = floodFill(from: pos, color: block.color, grid: grid, visited: &visited)

                if group.count >= GameConstants.minGroupSize {
                    // Collect block IDs before clearing
                    let blockIDs = group.compactMap { grid[$0.row][$0.col]?.id }

                    events.append(BlastEvent(
                        clearedPositions: group,
                        clearedBlockIDs: blockIDs,
                        groupColor: block.color,
                        cascadeLevel: cascadeLevel
                    ))

                    // Clear the cells
                    for p in group {
                        grid[p.row][p.col] = nil
                    }
                }
            }
        }

        return events
    }

    // MARK: - Flood Fill

    /// BFS flood-fill from a starting position, collecting all orthogonally connected
    /// blocks of the given color. All visited positions are added to the visited set.
    private func floodFill(
        from start: GridPosition,
        color: BlockColor,
        grid: [[Block?]],
        visited: inout Set<GridPosition>
    ) -> [GridPosition] {
        var group: [GridPosition] = []
        var queue: [GridPosition] = [start]
        visited.insert(start)

        while !queue.isEmpty {
            let current = queue.removeFirst()
            group.append(current)

            for dir in Self.directions {
                let neighbor = GridPosition(row: current.row + dir.row, col: current.col + dir.col)

                guard neighbor.isValid,
                      !visited.contains(neighbor),
                      let neighborBlock = grid[neighbor.row][neighbor.col],
                      neighborBlock.color == color else { continue }

                visited.insert(neighbor)
                queue.append(neighbor)
            }
        }

        return group
    }
}
