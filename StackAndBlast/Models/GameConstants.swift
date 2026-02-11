import Foundation

/// Game-wide constants from the GDD.
enum GameConstants {
    /// Grid dimensions — reads from user settings (8, 9, 10, or 12).
    static var gridSize: Int { SettingsManager.shared.gridSize }

    /// Number of pieces presented per tray.
    static let piecesPerTray = 3

    /// Maximum cascade depth to prevent infinite loops.
    static let maxCascadeDepth = 10

    // MARK: - Blast Threshold (progressive, scaled by grid size)

    /// Starting minimum group size to trigger a blast.
    static var initialMinGroupSize: Int {
        switch gridSize {
        case 8:  return 8
        case 10: return 12
        case 12: return 16
        default: return 10 // 9x9
        }
    }

    /// Maximum minimum group size (cap).
    static var maxMinGroupSize: Int {
        switch gridSize {
        case 8:  return 12
        case 10: return 16
        case 12: return 20
        default: return 14 // 9x9
        }
    }

    /// Score interval at which the minimum group size increases by 1.
    static let groupSizeIncreaseInterval = 500

    // MARK: - Scoring

    /// Points awarded per cell when placing a piece.
    static let pointsPerCell = 1

    /// Points per cell cleared in a blast group.
    static let baseBlastScore = 20

    /// Bonus points for larger groups — (minimum size, bonus points).
    static var groupBonusThresholds: [(size: Int, bonus: Int)] {
        let b = initialMinGroupSize
        return [(b, 0), (b + 1, 50), (b + 2, 150), (b + 4, 300)]
    }

    // MARK: - Daily Challenge

    /// Duration of the Daily Challenge mode in seconds.
    static let dailyChallengeDuration: Double = 60.0

    // MARK: - Power-Ups

    /// A power-up spawns on the grid every N pieces placed.
    static let powerUpSpawnInterval = 8

    // MARK: - Animation durations (seconds)

    static let placementBounceDuration: Double = 0.15
    static let detonateFlashDuration: Double = 0.1
    static let shockwaveFadeDuration: Double = 0.4
    static let pushAnimationDuration: Double = 0.2
}
