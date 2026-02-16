import Foundation
import Observation

/// Tracks daily login streaks and awards escalating coin rewards.
/// Reward schedule cycles every 7 days: [50, 100, 150, 150, 200, 300, 500].
@Observable
final class StreakManager {

    static let shared = StreakManager()

    /// Coin rewards for days 1–7, cycling.
    static let rewardSchedule = [50, 100, 150, 150, 200, 300, 500]

    private let defaults = UserDefaults.standard
    private let calendar = Calendar.current

    // MARK: - State

    private(set) var currentStreak: Int {
        didSet { defaults.set(currentStreak, forKey: "streak_currentStreak") }
    }

    private(set) var lastClaimDate: Date? {
        didSet { defaults.set(lastClaimDate, forKey: "streak_lastClaimDate") }
    }

    /// Whether the player has already claimed today's reward.
    var hasClaimedToday: Bool {
        guard let lastClaim = lastClaimDate else { return false }
        return calendar.isDateInToday(lastClaim)
    }

    /// The coin reward for the current streak day (0-indexed into cycling schedule).
    var todayReward: Int {
        let dayIndex = currentStreak % Self.rewardSchedule.count
        return Self.rewardSchedule[dayIndex]
    }

    // MARK: - Init

    private init() {
        currentStreak = defaults.integer(forKey: "streak_currentStreak")
        lastClaimDate = defaults.object(forKey: "streak_lastClaimDate") as? Date

        // Reset streak if player missed a day
        if let lastClaim = lastClaimDate {
            if !calendar.isDateInToday(lastClaim) && !calendar.isDateInYesterday(lastClaim) {
                // Missed at least one day — reset streak
                currentStreak = 0
            }
        }
    }

    // MARK: - Actions

    /// Claim today's daily reward. Returns the number of coins awarded, or 0 if already claimed.
    @discardableResult
    func claimDailyReward() -> Int {
        guard !hasClaimedToday else { return 0 }

        let reward = todayReward
        currentStreak += 1
        lastClaimDate = Date()

        CoinManager.shared.earn(reward, source: "daily_streak")
        AnalyticsManager.shared.logDailyLoginStreak(day: currentStreak, coinsAwarded: reward)

        return reward
    }
}
