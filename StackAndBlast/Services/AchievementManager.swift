import Foundation
import Observation

/// Definition of a single achievement.
struct Achievement: Identifiable {
    let id: String
    let name: String
    let description: String
    let icon: String
    let coinReward: Int
    /// Closure that checks if the condition is met, given current game stats.
    let condition: () -> Bool
}

/// Manages achievement tracking, unlocking, and coin rewards.
@Observable
final class AchievementManager {

    static let shared = AchievementManager()

    private let defaults = UserDefaults.standard

    // MARK: - State

    /// IDs of all unlocked achievements.
    private(set) var unlockedIDs: Set<String> {
        didSet { defaults.set(Array(unlockedIDs), forKey: "achievements_unlockedIDs") }
    }

    /// Most recently unlocked achievement (for toast display). Cleared after showing.
    var recentlyUnlocked: Achievement?

    /// All achievement definitions.
    let achievements: [Achievement]

    // MARK: - Init

    private init() {
        let savedIDs = UserDefaults.standard.stringArray(forKey: "achievements_unlockedIDs") ?? []
        unlockedIDs = Set(savedIDs)

        let stats = StatsManager.shared

        achievements = [
            Achievement(
                id: "first_blast",
                name: "First Blast",
                description: "Trigger your first blast",
                icon: "flame",
                coinReward: 50,
                condition: { stats.totalBlasts >= 1 }
            ),
            Achievement(
                id: "chain_master",
                name: "Chain Master",
                description: "Get a 3x combo in a single move",
                icon: "link",
                coinReward: 100,
                condition: { stats.highestCombo >= 3 }
            ),
            Achievement(
                id: "centurion",
                name: "Centurion",
                description: "Score 100+ in a single game",
                icon: "shield.fill",
                coinReward: 100,
                condition: { stats.highestSingleGameScore >= 100 }
            ),
            Achievement(
                id: "speed_demon",
                name: "Speed Demon",
                description: "Place 50 pieces in a single game",
                icon: "bolt.fill",
                coinReward: 150,
                condition: {
                    // Checked at game over with current game stats
                    stats.totalPiecesPlaced >= 50
                }
            ),
            Achievement(
                id: "marathoner",
                name: "Marathoner",
                description: "Play 25 games",
                icon: "figure.run",
                coinReward: 200,
                condition: { stats.totalGamesPlayed >= 25 }
            ),
            Achievement(
                id: "high_roller",
                name: "High Roller",
                description: "Score 500+ in a single game",
                icon: "star.fill",
                coinReward: 150,
                condition: { stats.highestSingleGameScore >= 500 }
            ),
            Achievement(
                id: "blast_legend",
                name: "Blast Legend",
                description: "Trigger 500 total blasts",
                icon: "flame.fill",
                coinReward: 300,
                condition: { stats.totalBlasts >= 500 }
            ),
            Achievement(
                id: "piece_master",
                name: "Piece Master",
                description: "Place 1,000 pieces total",
                icon: "square.grid.3x3.fill",
                coinReward: 200,
                condition: { stats.totalPiecesPlaced >= 1000 }
            ),
            Achievement(
                id: "cascade_king",
                name: "Cascade King",
                description: "Get a 5x combo in a single move",
                icon: "crown.fill",
                coinReward: 500,
                condition: { stats.highestCombo >= 5 }
            ),
            Achievement(
                id: "five_thousand",
                name: "Five Thousand",
                description: "Score 5,000+ in a single game",
                icon: "trophy.fill",
                coinReward: 500,
                condition: { stats.highestSingleGameScore >= 5000 }
            )
        ]
    }

    // MARK: - Check

    /// Check all achievements and unlock any newly qualified ones.
    /// Call after each game over.
    func checkAchievements() {
        for achievement in achievements {
            if !unlockedIDs.contains(achievement.id) && achievement.condition() {
                unlockAchievement(achievement)
            }
        }
    }

    /// Whether a specific achievement is unlocked.
    func isUnlocked(_ id: String) -> Bool {
        unlockedIDs.contains(id)
    }

    // MARK: - Private

    private func unlockAchievement(_ achievement: Achievement) {
        unlockedIDs.insert(achievement.id)
        recentlyUnlocked = achievement

        CoinManager.shared.earn(achievement.coinReward, source: "achievement_\(achievement.id)")
        AnalyticsManager.shared.logAchievementUnlocked(
            id: achievement.id,
            coinReward: achievement.coinReward
        )
    }
}
