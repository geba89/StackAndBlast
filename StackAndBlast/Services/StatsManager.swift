import Foundation

/// Tracks lifetime statistics across all game sessions.
/// Persists to UserDefaults and provides a method to record game results.
@Observable
final class StatsManager {

    static let shared = StatsManager()

    private let defaults = UserDefaults.standard

    // MARK: - Lifetime Stats

    private(set) var totalGamesPlayed: Int {
        didSet { defaults.set(totalGamesPlayed, forKey: "stats_totalGamesPlayed") }
    }

    private(set) var totalScore: Int {
        didSet { defaults.set(totalScore, forKey: "stats_totalScore") }
    }

    private(set) var totalBlasts: Int {
        didSet { defaults.set(totalBlasts, forKey: "stats_totalBlasts") }
    }

    private(set) var totalPiecesPlaced: Int {
        didSet { defaults.set(totalPiecesPlaced, forKey: "stats_totalPiecesPlaced") }
    }

    private(set) var highestCombo: Int {
        didSet { defaults.set(highestCombo, forKey: "stats_highestCombo") }
    }

    private(set) var highestSingleGameScore: Int {
        didSet { defaults.set(highestSingleGameScore, forKey: "stats_highestSingleGameScore") }
    }

    // MARK: - Init

    private init() {
        totalGamesPlayed = defaults.integer(forKey: "stats_totalGamesPlayed")
        totalScore = defaults.integer(forKey: "stats_totalScore")
        totalBlasts = defaults.integer(forKey: "stats_totalBlasts")
        totalPiecesPlaced = defaults.integer(forKey: "stats_totalPiecesPlaced")
        highestCombo = defaults.integer(forKey: "stats_highestCombo")
        highestSingleGameScore = defaults.integer(forKey: "stats_highestSingleGameScore")
    }

    // MARK: - Recording

    /// Record accumulative stats once per game (totals that should not be double-counted).
    func recordGameTotals(score: Int, blasts: Int, piecesPlaced: Int) {
        totalGamesPlayed += 1
        totalScore += score
        totalBlasts += blasts
        totalPiecesPlaced += piecesPlaced
    }

    /// Update "best of" records. Safe to call multiple times per game (e.g. after bomb continue).
    func updateBests(score: Int, maxCombo: Int) {
        if maxCombo > highestCombo { highestCombo = maxCombo }
        if score > highestSingleGameScore { highestSingleGameScore = score }
    }
}
