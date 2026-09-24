import Foundation
import Observation

/// Tracks today's three daily missions: counts gameplay events, pays coins when a
/// mission is completed, and a bonus for finishing all three. Missions and progress
/// start over at local midnight.
@Observable
final class MissionManager {

    static let shared = MissionManager()

    /// Coins for completing all three of the day's missions.
    static let allCompleteBonus = 70

    // MARK: - State

    /// Day the current missions belong to ("yyyy-MM-dd").
    private(set) var dayKey: String

    /// Today's missions: easy, medium, hard.
    private(set) var missions: [DailyMission]

    /// Progress for each mission, in the same order as `missions`.
    private(set) var progress: [Int]

    /// Whether today's all-three bonus has been paid.
    private(set) var bonusAwarded: Bool

    /// The mission completed most recently, for the "Mission complete!" toast.
    /// The UI clears it after showing.
    var recentlyCompleted: DailyMission?

    /// How many of today's missions are done.
    var completedCount: Int { missions.indices.filter(isCompleted).count }

    func isCompleted(_ index: Int) -> Bool {
        progress[index] >= missions[index].target
    }

    // MARK: - Dependencies (swappable in tests)

    private let defaults: UserDefaults
    /// Today's day key (tests fake the date by passing their own).
    private let today: () -> String
    /// Pays out coins: (amount, source).
    private let award: (Int, String) -> Void

    init(defaults: UserDefaults = .standard,
         today: @escaping () -> String = { DailyChallengeDate.key() },
         award: @escaping (Int, String) -> Void = { CoinManager.shared.earn($0, source: $1) }) {
        self.defaults = defaults
        self.today = today
        self.award = award

        // Locals first: `self` can't be read until every stored property has a value
        let key = today()
        let todaysMissions = DailyMission.missions(forDay: key)
        dayKey = key
        missions = todaysMissions

        // Pick up saved progress if it's from today
        if defaults.string(forKey: Keys.day) == key,
           let saved = defaults.array(forKey: Keys.progress) as? [Int],
           saved.count == todaysMissions.count {
            progress = saved
            bonusAwarded = defaults.bool(forKey: Keys.bonusAwarded)
        } else {
            progress = Array(repeating: 0, count: todaysMissions.count)
            bonusAwarded = false
        }
    }

    // MARK: - Updating

    /// Switch to fresh missions if the day changed since these were picked
    /// (the app can stay open across midnight).
    func refreshIfNewDay() {
        let key = today()
        guard key != dayKey else { return }
        dayKey = key
        missions = DailyMission.missions(forDay: key)
        progress = Array(repeating: 0, count: missions.count)
        bonusAwarded = false
        save()
    }

    /// Count a gameplay event towards today's missions and pay for any it completes.
    func record(_ event: MissionEvent) {
        refreshIfNewDay()
        var changed = false

        for index in missions.indices {
            let before = progress[index]
            let after = missions[index].progress(after: event, from: before)
            guard after != before else { continue }
            progress[index] = after
            changed = true

            // Crossing the target pays exactly once (progress is saved, never lowered)
            let target = missions[index].target
            if before < target && after >= target {
                award(missions[index].reward, "mission")
                recentlyCompleted = missions[index]
            }
        }

        if !bonusAwarded && completedCount == missions.count {
            bonusAwarded = true
            award(Self.allCompleteBonus, "mission_bonus")
            changed = true
        }

        if changed { save() }
    }

    // MARK: - Persistence

    private func save() {
        defaults.set(dayKey, forKey: Keys.day)
        defaults.set(progress, forKey: Keys.progress)
        defaults.set(bonusAwarded, forKey: Keys.bonusAwarded)
    }

    private enum Keys {
        static let day = "missions_day"
        static let progress = "missions_progress"
        static let bonusAwarded = "missions_bonusAwarded"
    }
}
