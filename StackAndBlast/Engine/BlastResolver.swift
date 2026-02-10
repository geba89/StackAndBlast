import Foundation

/// Detects connected color groups, clears them, and pushes ALL adjacent
/// blocks 1 cell away from the blast with chain-pushing (domino effect).
final class BlastResolver {

    /// Orthogonal neighbor offsets: up, down, left, right.
    private static let directions = [
        (row: -1, col: 0), // up
        (row: 1, col: 0),  // down
        (row: 0, col: -1), // left
        (row: 0, col: 1)   // right
    ]

    /// Scan the grid for connected color groups >= minGroupSize.
    /// Clears qualifying groups, chain-pushes adjacent blocks outward.
    /// Mutates the grid in place. Returns empty array if no groups qualify.
    func resolve(grid: inout [[Block?]], cascadeLevel: Int, minGroupSize: Int) -> [BlastEvent] {
        var visited = Set<GridPosition>()
        var events: [BlastEvent] = []

        for row in 0..<GameConstants.gridSize {
            for col in 0..<GameConstants.gridSize {
                let pos = GridPosition(row: row, col: col)
                guard !visited.contains(pos),
                      let block = grid[row][col] else { continue }

                let group = floodFill(from: pos, color: block.color, grid: grid, visited: &visited)

                if group.count >= minGroupSize {
                    let blockIDs = group.compactMap { grid[$0.row][$0.col]?.id }
                    let clearedSet = Set(group)

                    // Clear the cells
                    for p in group {
                        grid[p.row][p.col] = nil
                    }

                    // Chain-push ALL adjacent blocks outward
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

    // MARK: - Chain Push

    /// Push ALL blocks adjacent to the cleared group 1 cell away from the
    /// blast center. If a block is in the way, it gets chain-pushed too
    /// (domino effect). Blocks pushed off the grid are destroyed.
    private func pushAdjacentBlocks(
        clearedGroup: Set<GridPosition>,
        grid: inout [[Block?]]
    ) -> [PushedBlock] {
        // Center of the cleared group
        let centerRow = Double(clearedGroup.map(\.row).reduce(0, +)) / Double(clearedGroup.count)
        let centerCol = Double(clearedGroup.map(\.col).reduce(0, +)) / Double(clearedGroup.count)

        // Find ALL occupied cells adjacent to the cleared area
        var adjacentPositions: [GridPosition] = []
        var seen = Set<GridPosition>()
        for pos in clearedGroup {
            for dir in Self.directions {
                let neighbor = GridPosition(row: pos.row + dir.row, col: pos.col + dir.col)
                if neighbor.isValid,
                   !clearedGroup.contains(neighbor),
                   !seen.contains(neighbor),
                   grid[neighbor.row][neighbor.col] != nil {
                    adjacentPositions.append(neighbor)
                    seen.insert(neighbor)
                }
            }
        }

        // Sort by distance from center (farthest first) to avoid conflicts
        // when applying chain pushes
        adjacentPositions.sort { a, b in
            let distA = abs(Double(a.row) - centerRow) + abs(Double(a.col) - centerCol)
            let distB = abs(Double(b.row) - centerRow) + abs(Double(b.col) - centerCol)
            return distA > distB
        }

        var allPushed: [PushedBlock] = []

        for pos in adjacentPositions {
            // Skip if this block was already moved by a previous chain push
            guard grid[pos.row][pos.col] != nil else { continue }

            // Calculate push direction: away from blast center
            let dRow = Double(pos.row) - centerRow
            let dCol = Double(pos.col) - centerCol

            let pushDir: (row: Int, col: Int)
            if abs(dRow) >= abs(dCol) {
                pushDir = (row: dRow >= 0 ? 1 : -1, col: 0)
            } else {
                pushDir = (row: 0, col: dCol >= 0 ? 1 : -1)
            }

            // Chain-push: trace along the push direction, collecting all
            // consecutive blocks that need to move
            let chainResult = resolveChainPush(
                startingAt: pos,
                direction: pushDir,
                grid: &grid
            )
            allPushed.append(contentsOf: chainResult)
        }

        return allPushed
    }

    /// Resolve a chain push starting from `start` in `direction`.
    /// All consecutive blocks along the line shift 1 cell.
    /// The last block either lands in an empty cell or falls off the grid.
    private func resolveChainPush(
        startingAt start: GridPosition,
        direction dir: (row: Int, col: Int),
        grid: inout [[Block?]]
    ) -> [PushedBlock] {
        // Collect the chain of consecutive occupied cells in the push direction
        var chain: [GridPosition] = []
        var current = start

        while current.isValid, grid[current.row][current.col] != nil {
            chain.append(current)
            current = GridPosition(row: current.row + dir.row, col: current.col + dir.col)
        }

        guard !chain.isEmpty else { return [] }

        var results: [PushedBlock] = []

        // Process chain from the END to avoid overwriting
        // `current` is now the first empty cell (or off-grid) after the chain
        let lastDest = GridPosition(row: chain.last!.row + dir.row, col: chain.last!.col + dir.col)

        if !lastDest.isValid {
            // Last block in chain falls off the grid — destroyed
            let lastPos = chain.last!
            let lastBlock = grid[lastPos.row][lastPos.col]!
            results.append(PushedBlock(blockID: lastBlock.id, from: lastPos, to: nil))
            grid[lastPos.row][lastPos.col] = nil
        }

        // Shift all blocks in the chain 1 cell in the push direction
        // (process from end to start to avoid overwrites)
        for i in stride(from: chain.count - 1, through: 0, by: -1) {
            let fromPos = chain[i]
            guard let block = grid[fromPos.row][fromPos.col] else { continue }

            let toPos = GridPosition(row: fromPos.row + dir.row, col: fromPos.col + dir.col)

            if toPos.isValid {
                // Move block to new position
                var movedBlock = block
                movedBlock.position = toPos
                grid[toPos.row][toPos.col] = movedBlock
                grid[fromPos.row][fromPos.col] = nil
                results.append(PushedBlock(blockID: block.id, from: fromPos, to: toPos))
            } else {
                // Already handled the off-grid case for the last block above;
                // for any other block pushed off-grid (shouldn't happen with
                // single-cell pushes, but just in case):
                grid[fromPos.row][fromPos.col] = nil
                if !results.contains(where: { $0.blockID == block.id }) {
                    results.append(PushedBlock(blockID: block.id, from: fromPos, to: nil))
                }
            }
        }

        return results
    }
}
