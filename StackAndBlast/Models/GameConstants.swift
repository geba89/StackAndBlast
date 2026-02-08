import Foundation

/// Game-wide constants from the GDD.
enum GameConstants {
    /// Grid dimensions (9×9).
    static let gridSize = 9

    /// Number of pieces presented per tray.
    static let piecesPerTray = 3

    /// Maximum cascade depth to prevent infinite loops (GDD section 14).
    static let maxCascadeDepth = 10

    // MARK: - Scoring (GDD section 4.1)

    static let pointsPerCell = 1
    static let singleLineBlast = 100
    static let doubleLineBlast = 300
    static let tripleLineBlast = 600
    static let quadPlusLineBlast = 1000
    static let crossBlastBonus = 500

    // MARK: - Animation durations (seconds)

    static let placementBounceDuration: Double = 0.15
    static let detonateFlashDuration: Double = 0.1
    static let swapAnimationDuration: Double = 0.25
    static let pushSettleDuration: Double = 0.3
    static let shockwaveFadeDuration: Double = 0.4
}
