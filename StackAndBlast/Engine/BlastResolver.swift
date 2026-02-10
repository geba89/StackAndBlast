import Foundation

/// Detects connected color groups (8+ orthogonally adjacent blocks of the same color),
/// clears them, and pushes adjacent blocks 1 cell away from the blast.
final class BlastResolver {

    /// Orthogonal neighbor offsets: up, down, left, right.
    private static let directions = [
        (row: -1, col: 0), // up
        (row: 1, col: 0),  // down
        (row: 0, col: -1), // left
        (row: 0, col: 1)   // right
    ]

    /// Scan the grid for connected color groups of 8+ blocks.
    /// Clears qualifying groups, pushes adjacent blocks outward, and returns blast events.
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
                    let clearedSet = Set(group)

                    // Clear the cells
                    for p in group {
                        grid[p.row][p.col] = nil
                    }

                    // Push adjacent blocks 1 cell away from the blast center
                    let pushedBlocks = pushAdjacentBlocks(
                        clearedGroup: clearedSet,
                        grid: &grid
                    )

                    events.append(BlastEvent(
                        clearedPositions: group,
                        clearedBlockIDs: blockIDs,
                        groupColor: block.color,
                        cascadeLevel: cascadeLevel,
                        pushedBlocks: pushedBlocks
                    ))
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

    // MARK: - Push Mechanic

    /// Find all blocks adjacent to the cleared group and push them 1 cell
    /// away from the blast center. Blocks pushed off the grid are destroyed.
    private func pushAdjacentBlocks(
        clearedGroup: Set<GridPosition>,
        grid: inout [[Block?]]
    ) -> [PushedBlock] {
        // Calculate the center of the cleared group
        let centerRow = Double(clearedGroup.map(\.row).reduce(0, +)) / Double(clearedGroup.count)
        let centerCol = Double(clearedGroup.map(\.col).reduce(0, +)) / Double(clearedGroup.count)

        // Find all occupied cells adjacent to the cleared area
        var adjacentPositions = Set<GridPosition>()
        for pos in clearedGroup {
            for dir in Self.directions {
                let neighbor = GridPosition(row: pos.row + dir.row, col: pos.col + dir.col)
                if neighbor.isValid,
                   !clearedGroup.contains(neighbor),
                   grid[neighbor.row][neighbor.col] != nil {
                    adjacentPositions.insert(neighbor)
                }
            }
        }

        // Calculate push direction for each adjacent block and apply
        var pushedBlocks: [PushedBlock] = []
        // Process pushes: first collect all moves, then apply to avoid conflicts
        var moves: [(from: GridPosition, to: GridPosition?, block: Block)] = []

        for pos in adjacentPositions {
            guard let block = grid[pos.row][pos.col] else { continue }

            // Direction away from blast center (snap to cardinal)
            let dRow = Double(pos.row) - centerRow
            let dCol = Double(pos.col) - centerCol

            let pushDir: (row: Int, col: Int)
            if abs(dRow) >= abs(dCol) {
                // Vertical push dominates
                pushDir = (row: dRow >= 0 ? 1 : -1, col: 0)
            } else {
                // Horizontal push dominates
                pushDir = (row: 0, col: dCol >= 0 ? 1 : -1)
            }

            let newPos = GridPosition(row: pos.row + pushDir.row, col: pos.col + pushDir.col)

            if !newPos.isValid {
                // Pushed off the grid — block is destroyed
                moves.append((from: pos, to: nil, block: block))
            } else if grid[newPos.row][newPos.col] == nil && !clearedGroup.contains(newPos) {
                // Destination is empty — move the block
                moves.append((from: pos, to: newPos, block: block))
            }
            // If destination is occupied, block stays in place (no push)
        }

        // Apply all moves to the grid
        for move in moves {
            grid[move.from.row][move.from.col] = nil

            if let dest = move.to {
                var movedBlock = move.block
                movedBlock.position = dest
                grid[dest.row][dest.col] = movedBlock
            }

            pushedBlocks.append(PushedBlock(
                blockID: move.block.id,
                from: move.from,
                to: move.to
            ))
        }

        return pushedBlocks
    }
}
