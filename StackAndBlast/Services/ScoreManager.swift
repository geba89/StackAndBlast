import Foundation

/// Persists high scores using UserDefaults.
/// Tracks best scores per game mode (GDD section 10.1).
@Observable
final class ScoreManager {

    static let shared = ScoreManager()

    private let defaults = UserDefaults.standard

    /// Best score in Classic mode.
    private(set) var classicHighScore: Int {
        didSet { defaults.set(classicHighScore, forKey: "classicHighScore") }
    }

    /// Best score in Blast Rush mode.
    private(set) var blastRushHighScore: Int {
        didSet { defaults.set(blastRushHighScore, forKey: "blastRushHighScore") }
    }

    private init() {
        classicHighScore = defaults.integer(forKey: "classicHighScore")
        blastRushHighScore = defaults.integer(forKey: "blastRushHighScore")
    }

    /// Submit a score — updates high score if it's a new record.
    func submitScore(_ score: Int, mode: GameMode) {
        switch mode {
        case .classic:
            if score > classicHighScore { classicHighScore = score }
        case .blastRush:
            if score > blastRushHighScore { blastRushHighScore = score }
        case .dailyChallenge:
            break // Daily challenge uses separate leaderboard (future)
        }
    }

    /// Get the high score for a given mode.
    func highScore(for mode: GameMode) -> Int {
        switch mode {
        case .classic: return classicHighScore
        case .blastRush: return blastRushHighScore
        case .dailyChallenge: return 0
        }
    }
}
