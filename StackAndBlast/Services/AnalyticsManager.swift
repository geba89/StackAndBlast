import Foundation
import FirebaseAnalytics

/// Wraps Firebase Analytics with typed methods for each game event.
/// Plain singleton — no @Observable needed since it has no state to observe.
final class AnalyticsManager {

    static let shared = AnalyticsManager()

    private init() {}

    // MARK: - Game Events

    func logGameStart(mode: String) {
        Analytics.logEvent("game_start", parameters: ["mode": mode])
    }

    func logGameOver(mode: String, score: Int, blasts: Int, piecesPlaced: Int, maxCombo: Int) {
        Analytics.logEvent("game_over", parameters: [
            "mode": mode,
            "score": score,
            "blasts": blasts,
            "pieces_placed": piecesPlaced,
            "max_combo": maxCombo
        ])
    }

    // MARK: - Ad Events

    func logBombAdWatched(score: Int) {
        Analytics.logEvent("bomb_ad_watched", parameters: ["score_at_watch": score])
    }

    func logDoubleScoreAdWatched(originalScore: Int) {
        Analytics.logEvent("double_score_ad_watched", parameters: ["original_score": originalScore])
    }

    func logInterstitialShown(sessionGameCount: Int) {
        Analytics.logEvent("interstitial_shown", parameters: ["session_game_count": sessionGameCount])
    }

    // MARK: - Retention Events

    func logDailyChallengeCompleted(score: Int, tier: String) {
        Analytics.logEvent("daily_challenge_completed", parameters: [
            "score": score,
            "tier": tier
        ])
    }

    func logAchievementUnlocked(id: String, coinReward: Int) {
        Analytics.logEvent("achievement_unlocked", parameters: [
            "achievement_id": id,
            "coin_reward": coinReward
        ])
    }

    func logCoinsEarned(amount: Int, source: String) {
        Analytics.logEvent("coins_earned", parameters: [
            "amount": amount,
            "source": source
        ])
    }

    func logDailyLoginStreak(day: Int, coinsAwarded: Int) {
        Analytics.logEvent("daily_login_streak", parameters: [
            "streak_day": day,
            "coins_awarded": coinsAwarded
        ])
    }

    // MARK: - Coin Power-Up Events

    func logCoinPowerUpUsed(type: String, price: Int) {
        Analytics.logEvent("coin_powerup_used", parameters: [
            "type": type,
            "price": price
        ])
    }

    // MARK: - IAP Events

    func logIAPPurchase(productID: String, price: String) {
        Analytics.logEvent("iap_purchase", parameters: [
            "product_id": productID,
            "price": price
        ])
    }

    // MARK: - Leaderboard Events

    func logLeaderboardScoreSubmitted(mode: String, score: Int) {
        Analytics.logEvent("leaderboard_score_submitted", parameters: [
            "mode": mode,
            "score": score
        ])
    }

    // MARK: - Social Events

    func logShareScore(score: Int, mode: String) {
        Analytics.logEvent("share_score", parameters: [
            "score": score,
            "mode": mode
        ])
    }

    // MARK: - Settings Events

    func logSettingChanged(setting: String, value: String) {
        Analytics.logEvent("setting_changed", parameters: [
            "setting": setting,
            "value": value
        ])
    }

    func logSkinSelected(skinID: String) {
        Analytics.logEvent("skin_selected", parameters: ["skin_id": skinID])
    }

    func logSkinUnlocked(skinID: String) {
        Analytics.logEvent("skin_unlocked", parameters: ["skin_id": skinID])
    }
}
