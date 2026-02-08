import Foundation

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

    /// Highest combo reached in the current game.
    private(set) var maxCombo: Int = 0

    /// Total number of blasts triggered in the current game.
    private(set) var totalBlasts: Int = 0

    /// Total pieces placed.
    private(set) var piecesPlaced: Int = 0

    /// Current game state.
    private(set) var state: GameState = .menu

    // MARK: - Dependencies

    private let pieceGenerator = PieceGenerator()
    private let blastResolver = BlastResolver()

    // MARK: - Public API

    /// Start a new game: reset grid, score, and deal the first tray.
    func startNewGame() {
        grid = Array(
            repeating: Array(repeating: nil, count: GameConstants.gridSize),
            count: GameConstants.gridSize
        )
        score = 0
        maxCombo = 0
        totalBlasts = 0
        piecesPlaced = 0
        tray = pieceGenerator.generateTray()
        state = .playing
    }

    /// Attempt to place a piece at the given grid origin.
    /// Returns `true` if placement was valid and executed.
    @discardableResult
    func placePiece(_ piece: Piece, at origin: GridPosition) -> Bool {
        guard state == .playing else { return false }

        let positions = piece.absolutePositions(at: origin)

        // Validate: all positions must be in-bounds and empty
        guard positions.allSatisfy({ $0.isValid && grid[$0.row][$0.col] == nil }) else {
            return false
        }

        // Place blocks on the grid
        for pos in positions {
            grid[pos.row][pos.col] = Block(color: piece.color, position: pos)
        }

        score += piece.cellCount * GameConstants.pointsPerCell
        piecesPlaced += 1

        // Remove the placed piece from the tray
        tray.removeAll { $0.id == piece.id }

        // Check for line completions and resolve blasts
        resolveBlasts()

        // Refill tray if empty
        if tray.isEmpty {
            tray = pieceGenerator.generateTray()
        }

        // Check for game over
        if !canPlaceAnyPiece() {
            state = .gameOver
        }

        return true
    }

    // MARK: - Query

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

    /// Resolve all blast chains until no more lines are complete.
    private func resolveBlasts() {
        var cascadeLevel = 0

        while cascadeLevel < GameConstants.maxCascadeDepth {
            let events = blastResolver.resolve(grid: &grid, cascadeLevel: cascadeLevel)
            if events.isEmpty { break }

            // Score the blasts
            for event in events {
                let blastScore = calculateBlastScore(event: event, cascadeLevel: cascadeLevel)
                score += blastScore
                totalBlasts += 1
                maxCombo = max(maxCombo, cascadeLevel + 1)
            }

            cascadeLevel += 1
        }
    }

    /// Calculate score for a blast event using the GDD scoring table.
    private func calculateBlastScore(event: BlastEvent, cascadeLevel: Int) -> Int {
        let lineCount = event.totalLinesCleared
        let cascadeMultiplier = 1 << cascadeLevel // 1, 2, 4, 8...

        var base: Int
        switch lineCount {
        case 1: base = GameConstants.singleLineBlast
        case 2: base = GameConstants.doubleLineBlast
        case 3: base = GameConstants.tripleLineBlast
        default: base = GameConstants.quadPlusLineBlast
        }

        if event.isCrossBlast {
            base += GameConstants.crossBlastBonus
        }

        return base * cascadeMultiplier
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
}
