import Foundation

/// Decides when to ask for an App Store rating. Apple's own rating prompt does the
/// asking (see ContentView); this only picks a good moment:
/// - a happy one: a new personal best, or a gold medal in the Daily Challenge
/// - from a regular player: a few games played, installed for a couple of days
/// - rarely: once per app version, and weeks apart (Apple also shows its prompt
///   at most 3 times a year, and may decide not to show it at all)
///
/// No rewards: the App Store rules forbid paying players (coins included) for
/// ratings or reviews (guideline 3.2.2), and custom rating pop-ups (5.6.1).
final class ReviewPromptManager {
    static let shared = ReviewPromptManager()

    /// Finished games before we ask.
    static let minimumGamesPlayed = 5
    /// Days since the first launch before we ask.
    static let minimumDaysInstalled = 2
    /// Days between two asks.
    static let minimumDaysBetweenAsks = 60

    private let defaults: UserDefaults
    private let now: () -> Date
    private let appVersion: String

    /// - Parameters:
    ///   - defaults: where the dates are kept (tests pass their own)
    ///   - now: the clock (tests pass a fixed one)
    ///   - appVersion: the version asking — each version may ask once
    init(defaults: UserDefaults = .standard,
         now: @escaping () -> Date = Date.init,
         appVersion: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "") {
        self.defaults = defaults
        self.now = now
        self.appVersion = appVersion
        // Remember the first launch (created at app start, see StackAndBlastApp)
        if defaults.object(forKey: Keys.firstLaunch) == nil {
            defaults.set(now(), forKey: Keys.firstLaunch)
        }
    }

    /// Whether the game that just ended is a good moment to ask for a rating.
    func shouldAsk(isNewBest: Bool, isGoldMedal: Bool, gamesPlayed: Int) -> Bool {
        guard isNewBest || isGoldMedal else { return false }              // only happy moments
        guard gamesPlayed >= Self.minimumGamesPlayed else { return false } // they know the game
        let today = now()
        if let firstLaunch = defaults.object(forKey: Keys.firstLaunch) as? Date,
           today.timeIntervalSince(firstLaunch) < Self.days(Self.minimumDaysInstalled) {
            return false                                                  // not on day one
        }
        guard defaults.string(forKey: Keys.lastAskedVersion) != appVersion else {
            return false                                                  // once per version
        }
        if let lastAsked = defaults.object(forKey: Keys.lastAsked) as? Date,
           today.timeIntervalSince(lastAsked) < Self.days(Self.minimumDaysBetweenAsks) {
            return false                                                  // not too often
        }
        return true
    }

    /// Remember that we asked. (Whether Apple actually showed its prompt, or whether
    /// the player rated, is never told to the app.)
    func didAsk() {
        defaults.set(now(), forKey: Keys.lastAsked)
        defaults.set(appVersion, forKey: Keys.lastAskedVersion)
    }

    private static func days(_ count: Int) -> TimeInterval {
        TimeInterval(count) * 24 * 60 * 60
    }

    private enum Keys {
        static let firstLaunch = "review_firstLaunchDate"
        static let lastAsked = "review_lastAskedDate"
        static let lastAskedVersion = "review_lastAskedVersion"
    }
}
