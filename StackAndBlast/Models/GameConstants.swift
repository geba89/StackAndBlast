import Foundation

/// Game-wide constants from the GDD.
enum GameConstants {
    /// Grid dimensions (9x9).
    static let gridSize = 9

    /// Number of pieces presented per tray.
    static let piecesPerTray = 3

    /// Maximum cascade depth to prevent infinite loops.
    static let maxCascadeDepth = 10

    /// Minimum connected group size to trigger a blast.
    /// Set to 5 so placing a single 4-cell piece doesn't immediately blast.
    static let minGroupSize = 5

    // MARK: - Scoring

    /// Points awarded per cell when placing a piece.
    static let pointsPerCell = 1

    /// Points per cell cleared in a blast group.
    static let baseBlastScore = 20

    /// Bonus points for larger groups — (minimum size, bonus points).
    static let groupBonusThresholds: [(size: Int, bonus: Int)] = [
        (5, 0),
        (7, 50),
        (9, 150),
        (12, 300)
    ]

    // MARK: - Animation durations (seconds)

    static let placementBounceDuration: Double = 0.15
    static let detonateFlashDuration: Double = 0.1
    static let shockwaveFadeDuration: Double = 0.4
}
