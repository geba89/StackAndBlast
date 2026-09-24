import Foundation

/// Game-wide constants from the GDD.
enum GameConstants {
    /// Grid dimensions of the game in progress (8, 9, 10, or 12 — 7 in the tutorial).
    ///
    /// This is a snapshot taken when a game starts, NOT a live read of the setting.
    /// The engine's grid array is created with this size, so if it changed mid-game
    /// (e.g. from Settings in the pause menu), every loop over the grid would index
    /// past the end of the array and crash.
    private(set) static var gridSize: Int = SettingsManager.shared.gridSize

    /// Lock in the grid size for a new game. Called by `GameEngine` when a game starts.
    static func useGridSize(_ size: Int) {
        gridSize = size
    }

    /// The Daily Challenge is always played on the standard 9×9 board, so everyone
    /// really gets the same puzzle and daily scores are comparable.
    static let dailyChallengeGridSize = 9

    /// Number of pieces presented per tray.
    static let piecesPerTray = 3

    /// Maximum cascade depth to prevent infinite loops.
    static let maxCascadeDepth = 10

    // MARK: - Blast Threshold (progressive, scaled by grid size)

    /// Starting minimum group size to trigger a blast.
    static var initialMinGroupSize: Int { initialMinGroupSize(forGridSize: gridSize) }

    /// Starting minimum group size for a given grid size (also used for help texts,
    /// which describe the player's chosen grid rather than the one in progress).
    static func initialMinGroupSize(forGridSize size: Int) -> Int {
        switch size {
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

    // MARK: - Blast Rush

    /// Starting clock for Blast Rush in seconds.
    static let blastRushDuration: Double = 90.0

    /// Seconds added to the Blast Rush clock for every blast.
    static let blastRushTimeBonusPerBlast: Double = 5.0

    // MARK: - Power-Ups

    /// A power-up piece appears in the tray every N tray generations.
    static let powerUpTrayInterval = 3

    // MARK: - Coin Power-Ups

    /// Cost in coins to use a bomb during gameplay.
    static let coinBombPrice = 100
    /// Cost in coins to shuffle the tray.
    static let coinShufflePrice = 50
    /// Maximum coin-purchased bombs per game.
    static let maxCoinBombsPerGame = 1
    /// Maximum shuffles per game.
    static let maxShufflesPerGame = 3

    // MARK: - Animation durations (seconds)

    static let placementBounceDuration: Double = 0.15
    static let detonateFlashDuration: Double = 0.1
    static let shockwaveFadeDuration: Double = 0.4
    static let pushAnimationDuration: Double = 0.2
}
