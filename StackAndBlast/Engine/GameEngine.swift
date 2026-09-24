import Foundation
import Observation

/// Result of placing a piece — contains everything the view layer needs for animation.
struct PlacementResult {
    /// Whether placement was successful.
    let success: Bool
    /// Blast events in cascade order (empty if no groups cleared).
    let blastEvents: [BlastEvent]
    /// Grid snapshot BEFORE blasts resolved (for animation diffing). Nil if no blasts.
    let preBlastGrid: [[Block?]]?
    /// Whether the game ended after this placement.
    let gameOver: Bool

    /// Convenience for failed placements.
    static let failed = PlacementResult(success: false, blastEvents: [], preBlastGrid: nil, gameOver: false)
}

/// Result of using the bomb continue mechanic.
struct BombResult {
    let success: Bool
    let clearedPositions: [GridPosition]
    let clearedBlockIDs: [UUID]
    /// Whether the game can resume (at least one piece can be placed after clearing).
    let gameResumed: Bool
}

/// Core game logic: owns the grid state, handles placement, scoring, and blast resolution.
/// This is the "single source of truth" for the game — views observe it via GameViewModel.
@Observable
final class GameEngine {

    // MARK: - State

    /// The grid (`GameConstants.gridSize` × `GameConstants.gridSize`). `nil` means the cell is empty.
    private(set) var grid: [[Block?]] = Array(
        repeating: Array(repeating: nil, count: GameConstants.gridSize),
        count: GameConstants.gridSize
    )

    /// Current set of pieces available in the tray (up to 3).
    private(set) var tray: [Piece] = []

    /// Current score.
    private(set) var score: Int = 0

    /// Highest combo reached in the current game (total blasts from a single placement).
    private(set) var maxCombo: Int = 0

    /// Total number of blasts triggered in the current game.
    private(set) var totalBlasts: Int = 0

    /// Total pieces placed.
    private(set) var piecesPlaced: Int = 0

    /// Current game state.
    private(set) var state: GameState = .menu

    /// Whether the bomb continue has been used this game (max 1 per game).
    private(set) var hasContinued: Bool = false

    /// Whether this is a hand-made scenario (tutorial lesson): when the tray is used
    /// up it is not refilled — the engine waits for the next scenario instead.
    private(set) var isScenario: Bool = false

    /// Fixed blast goal for scenarios (`nil` = normal score-based goal).
    private var minGroupSizeOverride: Int?

    // MARK: - Dependencies

    let pieceGenerator = PieceGenerator()
    private let blastResolver = BlastResolver()

    // MARK: - Public API

    /// Start a new game: reset grid, score, and deal the first tray.
    func startNewGame() {
        // Lock in the grid size from Settings for this whole game
        GameConstants.useGridSize(SettingsManager.shared.gridSize)
        pieceGenerator.clearSeed()
        resetBoard()
        tray = pieceGenerator.generateTray()
        state = .playing
    }

    /// Start a Daily Challenge game with deterministic pieces based on today's date.
    func startDailyChallenge() {
        // Everyone plays the daily on the same board size, whatever their setting
        GameConstants.useGridSize(GameConstants.dailyChallengeGridSize)
        pieceGenerator.setSeed(PieceGenerator.seedForDate())
        resetBoard()
        tray = pieceGenerator.generateTray()
        state = .playing
    }

    /// Load a hand-made board, e.g. for a tutorial lesson or a unit test.
    ///
    /// - Parameters:
    ///   - scenarioGrid: a square grid; each block's `position` must match its cell
    ///     (`BoardSketch` takes care of that).
    ///   - scenarioTray: the exact pieces to offer. When they're used up the tray is
    ///     NOT refilled and the game doesn't end — the caller decides what's next.
    ///   - minGroupSize: fixed blast goal, or `nil` for the normal score-based goal.
    ///   - score: starting score (lets tests check score-dependent rules).
    func startScenario(grid scenarioGrid: [[Block?]], tray scenarioTray: [Piece], minGroupSize: Int?, score startingScore: Int = 0) {
        precondition(scenarioGrid.allSatisfy { $0.count == scenarioGrid.count }, "Scenario grid must be square")
        GameConstants.useGridSize(scenarioGrid.count)
        pieceGenerator.clearSeed()
        resetBoard()
        grid = scenarioGrid
        tray = scenarioTray
        score = startingScore
        isScenario = true
        minGroupSizeOverride = minGroupSize
        state = .playing
    }

    /// Attempt to place a piece at the given grid origin.
    /// Returns a `PlacementResult` with blast events and grid snapshot for animation.
    @discardableResult
    func placePiece(_ piece: Piece, at origin: GridPosition) -> PlacementResult {
        guard state == .playing else { return .failed }

        // Power-up pieces trigger their effect immediately instead of placing blocks
        if let powerUp = piece.powerUp {
            return activatePowerUp(powerUp, piece: piece, at: origin)
        }

        let positions = piece.absolutePositions(at: origin)

        // Validate: all positions must be in-bounds and empty
        guard positions.allSatisfy({ $0.isValid && grid[$0.row][$0.col] == nil }) else {
            return .failed
        }

        // The goal the player saw when dropping the piece is the one that applies.
        // (Read it BEFORE adding placement points — those could cross a 500-point
        // step and silently raise the goal for this very move.)
        let blastGoal = currentMinGroupSize

        // Place blocks on the grid
        for pos in positions {
            grid[pos.row][pos.col] = Block(color: piece.color, position: pos)
        }

        score += piece.cellCount * GameConstants.pointsPerCell
        piecesPlaced += 1

        // Remove the placed piece from the tray
        tray.removeAll { $0.id == piece.id }

        // Snapshot the grid BEFORE blast resolution (for animation diffing)
        let preBlastGrid = grid

        // Find color groups and resolve blasts (including cascades)
        let blastEvents = resolveBlasts(minGroupSize: blastGoal)

        // Track combo as total blast events from this single placement
        if !blastEvents.isEmpty {
            maxCombo = max(maxCombo, blastEvents.count)
        }

        let isGameOver = finishTurn()

        return PlacementResult(
            success: true,
            blastEvents: blastEvents,
            preBlastGrid: blastEvents.isEmpty ? nil : preBlastGrid,
            gameOver: isGameOver
        )
    }

    /// Pause the game.
    func pause() {
        guard state == .playing else { return }
        state = .paused
    }

    /// Resume from pause.
    func resume() {
        guard state == .paused else { return }
        state = .playing
    }

    /// Force end the game (e.g. timer ran out in Blast Rush mode).
    func endGame() {
        state = .gameOver
    }

    /// Add bonus points to the current score (e.g. from double-score ad reward).
    func addBonusScore(_ points: Int) {
        score += points
    }

    /// Regenerate the tray with new random pieces. Used by the coin-purchased Shuffle power-up.
    func shuffleTray() {
        tray = pieceGenerator.generateTray()
    }

    /// Use a coin-purchased bomb to clear a 6×6 area during active gameplay.
    /// Unlike `useBomb(at:)`, this works during `.playing` state and does not affect `hasContinued`.
    func useCoinBomb(at center: GridPosition) -> BombResult {
        guard state == .playing else {
            return BombResult(success: false, clearedPositions: [], clearedBlockIDs: [], gameResumed: true)
        }

        let cleared = clearBombArea(around: center)

        return BombResult(
            success: true,
            clearedPositions: cleared.positions,
            clearedBlockIDs: cleared.blockIDs,
            gameResumed: true
        )
    }

    /// Use the bomb to clear a 6×6 area centered on `center`. Limited to 1 per game.
    /// Does not trigger blast cascades — simply removes blocks in the area.
    func useBomb(at center: GridPosition) -> BombResult {
        guard state == .gameOver, !hasContinued else {
            return BombResult(success: false, clearedPositions: [], clearedBlockIDs: [], gameResumed: false)
        }

        let cleared = clearBombArea(around: center)
        hasContinued = true

        // Refill tray if empty
        if tray.isEmpty && !isScenario {
            tray = pieceGenerator.generateTray()
        }

        // Check if game can resume
        let canResume = canPlaceAnyPiece()
        if canResume {
            state = .playing
        }

        return BombResult(
            success: true,
            clearedPositions: cleared.positions,
            clearedBlockIDs: cleared.blockIDs,
            gameResumed: canResume
        )
    }

    // MARK: - Query

    /// Current minimum group size: grows by 1 every 500 points, up to a cap per grid size.
    var currentMinGroupSize: Int {
        if let fixedGoal = minGroupSizeOverride { return fixedGoal }
        let increases = score / GameConstants.groupSizeIncreaseInterval
        return min(GameConstants.initialMinGroupSize + increases, GameConstants.maxMinGroupSize)
    }

    /// Check if a piece can be placed at a given origin.
    func canPlace(_ piece: Piece, at origin: GridPosition) -> Bool {
        // Power-up pieces can be placed on any valid cell (they trigger instead of placing blocks)
        if piece.isPowerUp {
            return origin.isValid
        }
        let positions = piece.absolutePositions(at: origin)
        return positions.allSatisfy { $0.isValid && grid[$0.row][$0.col] == nil }
    }

    /// The block at a given grid position, if any.
    func block(at position: GridPosition) -> Block? {
        guard position.isValid else { return nil }
        return grid[position.row][position.col]
    }

    /// The same-color group a piece would form if dropped at `origin`: the piece's own
    /// cells plus every block of its color connected to them. Empty if the piece can't
    /// go there (or is a power-up). Used to preview blasts while dragging.
    func projectedGroup(for piece: Piece, at origin: GridPosition) -> [GridPosition] {
        guard !piece.isPowerUp, canPlace(piece, at: origin) else { return [] }

        // Flood fill (depth-first) starting from the piece's cells, which are all
        // connected and all the same color, walking through matching neighbors.
        let pieceCells = piece.absolutePositions(at: origin)
        var visited = Set(pieceCells)
        var toVisit = pieceCells
        var group: [GridPosition] = []

        while let current = toVisit.popLast() {
            group.append(current)
            for (dRow, dCol) in [(-1, 0), (1, 0), (0, -1), (0, 1)] {
                let neighbor = GridPosition(row: current.row + dRow, col: current.col + dCol)
                guard neighbor.isValid,
                      !visited.contains(neighbor),
                      grid[neighbor.row][neighbor.col]?.color == piece.color else { continue }
                visited.insert(neighbor)
                toVisit.append(neighbor)
            }
        }
        return group
    }

    // MARK: - Private

    /// Clear the board and per-game counters for a new game.
    private func resetBoard() {
        grid = Array(
            repeating: Array(repeating: nil, count: GameConstants.gridSize),
            count: GameConstants.gridSize
        )
        score = 0
        maxCombo = 0
        totalBlasts = 0
        piecesPlaced = 0
        hasContinued = false
        isScenario = false
        minGroupSizeOverride = nil
    }

    /// End-of-move bookkeeping: refill an empty tray and detect game over.
    /// Returns whether the game is over.
    private func finishTurn() -> Bool {
        if tray.isEmpty {
            // A scenario waits for its owner to hand out the next pieces
            if isScenario { return false }
            tray = pieceGenerator.generateTray()
        }

        if !canPlaceAnyPiece() {
            state = .gameOver
            return true
        }
        return false
    }

    /// Remove every block in the 6×6 bomb area: center −2…+3 rows and columns
    /// (clamped to the grid). Returns what was cleared, for animation.
    private func clearBombArea(around center: GridPosition) -> (positions: [GridPosition], blockIDs: [UUID]) {
        let minRow = max(center.row - 2, 0)
        let maxRow = min(center.row + 3, GameConstants.gridSize - 1)
        let minCol = max(center.col - 2, 0)
        let maxCol = min(center.col + 3, GameConstants.gridSize - 1)

        var clearedPositions: [GridPosition] = []
        var clearedBlockIDs: [UUID] = []

        for row in minRow...maxRow {
            for col in minCol...maxCol {
                if let block = grid[row][col] {
                    clearedPositions.append(GridPosition(row: row, col: col))
                    clearedBlockIDs.append(block.id)
                    grid[row][col] = nil
                }
            }
        }
        return (clearedPositions, clearedBlockIDs)
    }

    /// Resolve all blast chains until no more color groups qualify.
    /// Returns all blast events in cascade order for animation.
    private func resolveBlasts(minGroupSize: Int) -> [BlastEvent] {
        var allEvents: [BlastEvent] = []
        var cascadeLevel = 0

        while cascadeLevel < GameConstants.maxCascadeDepth {
            var events = blastResolver.resolve(grid: &grid, cascadeLevel: cascadeLevel, minGroupSize: minGroupSize)
            if events.isEmpty { break }

            for index in events.indices {
                let blastScore = calculateBlastScore(event: events[index], cascadeLevel: cascadeLevel)
                events[index].points = blastScore // shown as a floating "+points" popup
                score += blastScore
                totalBlasts += 1
            }

            allEvents.append(contentsOf: events)
            cascadeLevel += 1
        }

        return allEvents
    }

    /// Calculate score for a blast event: per-cell base + size bonus, scaled by cascade level.
    private func calculateBlastScore(event: BlastEvent, cascadeLevel: Int) -> Int {
        let cellScore = event.groupSize * GameConstants.baseBlastScore
        let sizeBonus = GameConstants.groupBonusThresholds
            .last(where: { event.groupSize >= $0.size })?.bonus ?? 0
        let cascadeMultiplier = 1 << cascadeLevel // 1, 2, 4, 8...
        return (cellScore + sizeBonus) * cascadeMultiplier
    }

    /// Check if any piece in the tray can be placed somewhere on the grid.
    private func canPlaceAnyPiece() -> Bool {
        for piece in tray {
            for row in 0..<GameConstants.gridSize {
                for col in 0..<GameConstants.gridSize {
                    if canPlace(piece, at: GridPosition(row: row, col: col)) {
                        return true
                    }
                }
            }
        }
        return false
    }

    // MARK: - Power-Ups

    /// Activate a power-up piece at the given grid position.
    /// Triggers the effect immediately and returns a PlacementResult for animation.
    private func activatePowerUp(_ type: PowerUpType, piece: Piece, at origin: GridPosition) -> PlacementResult {
        // Power-up pieces only need the origin cell to be valid
        guard origin.isValid else { return .failed }

        // Lock in the goal before scoring (see placePiece)
        let blastGoal = currentMinGroupSize

        piecesPlaced += 1

        // Remove the power-up piece from the tray
        tray.removeAll { $0.id == piece.id }

        // Snapshot the grid BEFORE power-up effect (for animation diffing)
        let preBlastGrid = grid

        // Apply the power-up effect
        var clearedPositions: [GridPosition] = []
        var clearedBlockIDs: [UUID] = []
        var effectColor: BlockColor = .coral

        switch type {
        case .colorBomb:
            // Find the most common color on the grid and clear all blocks of that color
            var colorCounts: [BlockColor: Int] = [:]
            for row in 0..<GameConstants.gridSize {
                for col in 0..<GameConstants.gridSize {
                    if let block = grid[row][col] {
                        colorCounts[block.color, default: 0] += 1
                    }
                }
            }
            guard let targetColor = colorCounts.max(by: { $0.value < $1.value })?.key else {
                // No blocks on the grid — still consume the piece
                if tray.isEmpty && !isScenario { tray = pieceGenerator.generateTray() }
                return PlacementResult(success: true, blastEvents: [], preBlastGrid: nil, gameOver: false)
            }
            effectColor = targetColor
            for row in 0..<GameConstants.gridSize {
                for col in 0..<GameConstants.gridSize {
                    if let block = grid[row][col], block.color == targetColor {
                        clearedPositions.append(GridPosition(row: row, col: col))
                        clearedBlockIDs.append(block.id)
                        grid[row][col] = nil
                    }
                }
            }

        case .rowBlast:
            for col in 0..<GameConstants.gridSize {
                if let block = grid[origin.row][col] {
                    clearedPositions.append(GridPosition(row: origin.row, col: col))
                    clearedBlockIDs.append(block.id)
                    grid[origin.row][col] = nil
                }
            }

        case .columnBlast:
            for row in 0..<GameConstants.gridSize {
                if let block = grid[row][origin.col] {
                    clearedPositions.append(GridPosition(row: row, col: origin.col))
                    clearedBlockIDs.append(block.id)
                    grid[row][origin.col] = nil
                }
            }
        }

        // Score the power-up clear
        let clearScore = clearedPositions.count * GameConstants.baseBlastScore
        score += clearScore
        if !clearedPositions.isEmpty { totalBlasts += 1 }

        var allEvents: [BlastEvent] = []

        if !clearedPositions.isEmpty {
            allEvents.append(BlastEvent(
                clearedPositions: clearedPositions,
                clearedBlockIDs: clearedBlockIDs,
                groupColor: effectColor,
                cascadeLevel: 0,
                pushedBlocks: [],
                triggeredPowerUps: [],
                powerUpSource: type,
                powerUpOrigin: origin,
                points: clearScore
            ))
        }

        // Resolve any cascading blasts caused by the power-up clear
        let cascadeEvents = resolveBlasts(minGroupSize: blastGoal)
        if !cascadeEvents.isEmpty {
            maxCombo = max(maxCombo, cascadeEvents.count)
        }
        allEvents.append(contentsOf: cascadeEvents)

        let isGameOver = finishTurn()

        return PlacementResult(
            success: true,
            blastEvents: allEvents,
            preBlastGrid: allEvents.isEmpty ? nil : preBlastGrid,
            gameOver: isGameOver
        )
    }
}
