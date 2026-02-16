import Foundation
import Observation

/// Tiered reward levels for daily challenge completion.
enum DailyChallengeTier: String, CaseIterable {
    case bronze
    case silver
    case gold

    var label: String {
        switch self {
        case .bronze: return "Bronze"
        case .silver: return "Silver"
        case .gold:   return "Gold"
        }
    }

    var icon: String {
        switch self {
        case .bronze: return "medal.fill"
        case .silver: return "medal.fill"
        case .gold:   return "medal.fill"
        }
    }

    var color: String {
        switch self {
        case .bronze: return "brown"
        case .silver: return "gray"
        case .gold:   return "yellow"
        }
    }

    var minimumScore: Int {
        switch self {
        case .bronze: return 0
        case .silver: return 1000
        case .gold:   return 2000
        }
    }

    var coinReward: Int {
        switch self {
        case .bronze: return 50
        case .silver: return 100
        case .gold:   return 200
        }
    }

    /// Determine the highest tier achieved for a given score.
    static func tierForScore(_ score: Int) -> DailyChallengeTier {
        if score >= DailyChallengeTier.gold.minimumScore { return .gold }
        if score >= DailyChallengeTier.silver.minimumScore { return .silver }
        return .bronze
    }
}

/// Manages daily challenge reward claiming and tracking.
@Observable
final class DailyChallengeRewardManager {

    static let shared = DailyChallengeRewardManager()

    private let defaults = UserDefaults.standard
    private let calendar = Calendar.current

    // MARK: - State

    /// Total daily challenges completed across all time.
    private(set) var totalCompleted: Int {
        didSet { defaults.set(totalCompleted, forKey: "dc_totalCompleted") }
    }

    /// The date of the last reward claim.
    private var lastRewardClaimDate: Date? {
        didSet { defaults.set(lastRewardClaimDate, forKey: "dc_lastRewardClaimDate") }
    }

    /// The tier achieved on the last claim today (nil if not yet claimed today).
    private(set) var lastTierAchieved: DailyChallengeTier? {
        didSet {
            defaults.set(lastTierAchieved?.rawValue, forKey: "dc_lastTierAchieved")
        }
    }

    /// Whether a daily challenge reward has already been claimed today.
    var hasClaimedToday: Bool {
        guard let lastClaim = lastRewardClaimDate else { return false }
        return calendar.isDateInToday(lastClaim)
    }

    // MARK: - Init

    private init() {
        totalCompleted = defaults.integer(forKey: "dc_totalCompleted")
        lastRewardClaimDate = defaults.object(forKey: "dc_lastRewardClaimDate") as? Date
        if let tierRaw = defaults.string(forKey: "dc_lastTierAchieved") {
            lastTierAchieved = DailyChallengeTier(rawValue: tierRaw)
        }

        // Reset tier if last claim was not today
        if let lastClaim = lastRewardClaimDate, !calendar.isDateInToday(lastClaim) {
            lastTierAchieved = nil
        }
    }

    // MARK: - Claim

    /// Claim the daily challenge reward for the given score.
    /// Returns the tier and coin reward, or nil if already claimed today.
    @discardableResult
    func claimReward(score: Int) -> (tier: DailyChallengeTier, coins: Int)? {
        guard !hasClaimedToday else { return nil }

        let tier = DailyChallengeTier.tierForScore(score)
        let coins = tier.coinReward

        totalCompleted += 1
        lastRewardClaimDate = Date()
        lastTierAchieved = tier

        CoinManager.shared.earn(coins, source: "daily_challenge_\(tier.rawValue)")
        AnalyticsManager.shared.logDailyChallengeCompleted(score: score, tier: tier.label)

        return (tier, coins)
    }
}
