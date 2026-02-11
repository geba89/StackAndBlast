import Foundation

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

    /// The 9×9 grid. `nil` means the cell is empty.
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

    // MARK: - Dependencies

    let pieceGenerator = PieceGenerator()
    private let blastResolver = BlastResolver()

    // MARK: - Public API

    /// Start a new game: reset grid, score, and deal the first tray.
    func startNewGame() {
        pieceGenerator.clearSeed()
        grid = Array(
            repeating: Array(repeating: nil, count: GameConstants.gridSize),
            count: GameConstants.gridSize
        )
        score = 0
        maxCombo = 0
        totalBlasts = 0
        piecesPlaced = 0
        hasContinued = false
        tray = pieceGenerator.generateTray()
        state = .playing
    }

    /// Start a Daily Challenge game with deterministic pieces based on today's date.
    func startDailyChallenge() {
        let seed = PieceGenerator.seedForDate()
        pieceGenerator.setSeed(seed)
        grid = Array(
            repeating: Array(repeating: nil, count: GameConstants.gridSize),
            count: GameConstants.gridSize
        )
        score = 0
        maxCombo = 0
        totalBlasts = 0
        piecesPlaced = 0
        hasContinued = false
        tray = pieceGenerator.generateTray()
        state = .playing
    }

    /// Attempt to place a piece at the given grid origin.
    /// Returns a `PlacementResult` with blast events and grid snapshot for animation.
    @discardableResult
    func placePiece(_ piece: Piece, at origin: GridPosition) -> PlacementResult {
        guard state == .playing else { return .failed }

        let positions = piece.absolutePositions(at: origin)

        // Validate: all positions must be in-bounds and empty
        guard positions.allSatisfy({ $0.isValid && grid[$0.row][$0.col] == nil }) else {
            return .failed
        }

        // Place blocks on the grid
        for pos in positions {
            grid[pos.row][pos.col] = Block(color: piece.color, position: pos)
        }

        score += piece.cellCount * GameConstants.pointsPerCell
        piecesPlaced += 1

        // Spawn a power-up every N pieces placed
        if piecesPlaced % GameConstants.powerUpSpawnInterval == 0 {
            spawnRandomPowerUp()
        }

        // Remove the placed piece from the tray
        tray.removeAll { $0.id == piece.id }

        // Snapshot the grid BEFORE blast resolution (for animation diffing)
        let preBlastGrid = grid

        // Check for line completions and resolve blasts
        let blastEvents = resolveBlasts()

        // Track combo as total blast events from this single placement
        if !blastEvents.isEmpty {
            maxCombo = max(maxCombo, blastEvents.count)
        }

        // Refill tray if empty
        if tray.isEmpty {
            tray = pieceGenerator.generateTray()
        }

        // Check for game over
        let isGameOver: Bool
        if !canPlaceAnyPiece() {
            state = .gameOver
            isGameOver = true
        } else {
            isGameOver = false
        }

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

    /// Use the bomb to clear a 6×6 area centered on `center`. Limited to 1 per game.
    /// Does not trigger blast cascades — simply removes blocks in the area.
    func useBomb(at center: GridPosition) -> BombResult {
        guard state == .gameOver, !hasContinued else {
            return BombResult(success: false, clearedPositions: [], clearedBlockIDs: [], gameResumed: false)
        }

        // 6×6 area: center ± 2 rows, center ± 2 cols (shifted +1 to make even size)
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

        hasContinued = true

        // Refill tray if empty
        if tray.isEmpty {
            tray = pieceGenerator.generateTray()
        }

        // Check if game can resume
        let canResume = canPlaceAnyPiece()
        if canResume {
            state = .playing
        }

        return BombResult(
            success: true,
            clearedPositions: clearedPositions,
            clearedBlockIDs: clearedBlockIDs,
            gameResumed: canResume
        )
    }

    // MARK: - Query

    /// Current minimum group size based on score progression (5 → 12).
    var currentMinGroupSize: Int {
        let increases = score / GameConstants.groupSizeIncreaseInterval
        return min(GameConstants.initialMinGroupSize + increases, GameConstants.maxMinGroupSize)
    }

    /// Check if a piece can be placed at a given origin.
    func canPlace(_ piece: Piece, at origin: GridPosition) -> Bool {
        let positions = piece.absolutePositions(at: origin)
        return positions.allSatisfy { $0.isValid && grid[$0.row][$0.col] == nil }
    }

    /// The block at a given grid position, if any.
    func block(at position: GridPosition) -> Block? {
        guard position.isValid else { return nil }
        return grid[position.row][position.col]
    }

    // MARK: - Private

    /// Resolve all blast chains until no more color groups qualify.
    /// Returns all blast events in cascade order for animation.
    private func resolveBlasts() -> [BlastEvent] {
        var allEvents: [BlastEvent] = []
        var cascadeLevel = 0

        let minGroupSize = currentMinGroupSize

        while cascadeLevel < GameConstants.maxCascadeDepth {
            let events = blastResolver.resolve(grid: &grid, cascadeLevel: cascadeLevel, minGroupSize: minGroupSize)
            if events.isEmpty { break }

            // Score the blasts and apply power-up effects
            var powerUpEvents: [BlastEvent] = []
            for event in events {
                let blastScore = calculateBlastScore(event: event, cascadeLevel: cascadeLevel)
                score += blastScore
                totalBlasts += 1

                // Apply any triggered power-up effects and collect their clear events
                for pu in event.triggeredPowerUps {
                    if let puEvent = applyPowerUpEffect(pu.type, at: pu.position, color: pu.color, cascadeLevel: cascadeLevel) {
                        powerUpEvents.append(puEvent)
                    }
                }
            }

            allEvents.append(contentsOf: events)
            // Power-up clear events come after the blast events at this cascade level
            allEvents.append(contentsOf: powerUpEvents)
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

    /// Place a random power-up block at a random empty cell on the grid.
    private func spawnRandomPowerUp() {
        // Collect all empty positions
        var emptyPositions: [GridPosition] = []
        for row in 0..<GameConstants.gridSize {
            for col in 0..<GameConstants.gridSize {
                if grid[row][col] == nil {
                    emptyPositions.append(GridPosition(row: row, col: col))
                }
            }
        }

        guard let pos = emptyPositions.randomElement() else { return }
        let color = BlockColor.allCases.randomElement()!
        let powerUp = PowerUpType.allCases.randomElement()!
        grid[pos.row][pos.col] = Block(color: color, position: pos, powerUp: powerUp)
    }

    /// Apply a power-up effect: clear cells based on the power-up type.
    /// Returns a BlastEvent describing which blocks were cleared (for animation),
    /// or nil if no blocks were actually cleared.
    private func applyPowerUpEffect(_ type: PowerUpType, at position: GridPosition, color: BlockColor, cascadeLevel: Int) -> BlastEvent? {
        var clearedPositions: [GridPosition] = []
        var clearedBlockIDs: [UUID] = []
        var effectColor = color

        switch type {
        case .colorBomb:
            // Pick a random OTHER color present on the grid → remove all blocks of that color
            var colorsOnGrid = Set<BlockColor>()
            for row in 0..<GameConstants.gridSize {
                for col in 0..<GameConstants.gridSize {
                    if let block = grid[row][col] {
                        colorsOnGrid.insert(block.color)
                    }
                }
            }
            colorsOnGrid.remove(color)
            guard let targetColor = colorsOnGrid.randomElement() else { return nil }
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
                if let block = grid[position.row][col] {
                    clearedPositions.append(GridPosition(row: position.row, col: col))
                    clearedBlockIDs.append(block.id)
                    grid[position.row][col] = nil
                }
            }

        case .columnBlast:
            for row in 0..<GameConstants.gridSize {
                if let block = grid[row][position.col] {
                    clearedPositions.append(GridPosition(row: row, col: position.col))
                    clearedBlockIDs.append(block.id)
                    grid[row][position.col] = nil
                }
            }
        }

        guard !clearedPositions.isEmpty else { return nil }

        return BlastEvent(
            clearedPositions: clearedPositions,
            clearedBlockIDs: clearedBlockIDs,
            groupColor: effectColor,
            cascadeLevel: cascadeLevel,
            pushedBlocks: [],
            triggeredPowerUps: [],
            powerUpSource: type,
            powerUpOrigin: position
        )
    }
}
