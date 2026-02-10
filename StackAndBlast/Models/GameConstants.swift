import Foundation

/// Game-wide constants from the GDD.
enum GameConstants {
    /// Grid dimensions (9x9).
    static let gridSize = 9

    /// Number of pieces presented per tray.
    static let piecesPerTray = 3

    /// Maximum cascade depth to prevent infinite loops.
    static let maxCascadeDepth = 10

    // MARK: - Blast Threshold (progressive)

    /// Starting minimum group size to trigger a blast.
    static let initialMinGroupSize = 10

    /// Maximum minimum group size (cap).
    static let maxMinGroupSize = 14

    /// Score interval at which the minimum group size increases by 1.
    static let groupSizeIncreaseInterval = 500

    // MARK: - Scoring

    /// Points awarded per cell when placing a piece.
    static let pointsPerCell = 1

    /// Points per cell cleared in a blast group.
    static let baseBlastScore = 20

    /// Bonus points for larger groups — (minimum size, bonus points).
    static let groupBonusThresholds: [(size: Int, bonus: Int)] = [
        (10, 0),
        (11, 50),
        (12, 150),
        (14, 300)
    ]

    // MARK: - Animation durations (seconds)

    static let placementBounceDuration: Double = 0.15
    static let detonateFlashDuration: Double = 0.1
    static let shockwaveFadeDuration: Double = 0.4
    static let pushAnimationDuration: Double = 0.2
}
