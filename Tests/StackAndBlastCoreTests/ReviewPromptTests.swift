import XCTest
@testable import StackAndBlastCore

/// When the game asks for an App Store rating (Apple's prompt does the asking).
final class ReviewPromptTests: XCTestCase {
    private var defaults: UserDefaults!
    /// A controllable clock, so the tests can jump days ahead.
    private var clock = Date(timeIntervalSince1970: 1_800_000_000)

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: "ReviewPromptTests-\(UUID().uuidString)")!
    }

    private func manager(version: String = "1.1.0") -> ReviewPromptManager {
        ReviewPromptManager(defaults: defaults, now: { [unowned self] in self.clock }, appVersion: version)
    }

    private func advance(days: Double) {
        clock += days * 24 * 60 * 60
    }

    func testAsksAtAHappyMomentOnceThePlayerIsSettledIn() {
        let reviews = manager() // first launch: now
        advance(days: 3)
        XCTAssertTrue(reviews.shouldAsk(isNewBest: true, isGoldMedal: false, gamesPlayed: 12))
        XCTAssertTrue(reviews.shouldAsk(isNewBest: false, isGoldMedal: true, gamesPlayed: 12))
    }

    func testNeverAfterAnOrdinaryGame() {
        let reviews = manager()
        advance(days: 30)
        XCTAssertFalse(reviews.shouldAsk(isNewBest: false, isGoldMedal: false, gamesPlayed: 100))
    }

    func testNotForBrandNewPlayers() {
        let reviews = manager()
        advance(days: 3)
        XCTAssertFalse(reviews.shouldAsk(isNewBest: true, isGoldMedal: false,
                                         gamesPlayed: ReviewPromptManager.minimumGamesPlayed - 1))

        let fresh = ReviewPromptManager(defaults: UserDefaults(suiteName: "fresh-\(UUID().uuidString)")!,
                                        now: { [unowned self] in self.clock }, appVersion: "1.1.0")
        advance(days: 1) // installed yesterday
        XCTAssertFalse(fresh.shouldAsk(isNewBest: true, isGoldMedal: false, gamesPlayed: 50))
    }

    func testOncePerVersion() {
        let reviews = manager(version: "1.1.0")
        advance(days: 3)
        XCTAssertTrue(reviews.shouldAsk(isNewBest: true, isGoldMedal: false, gamesPlayed: 10))
        reviews.didAsk()
        XCTAssertFalse(reviews.shouldAsk(isNewBest: true, isGoldMedal: false, gamesPlayed: 11))

        advance(days: 200) // long after, but still the same version
        XCTAssertFalse(manager(version: "1.1.0").shouldAsk(isNewBest: true, isGoldMedal: false, gamesPlayed: 90))
        XCTAssertTrue(manager(version: "1.2.0").shouldAsk(isNewBest: true, isGoldMedal: false, gamesPlayed: 90))
    }

    func testANewVersionStillWaitsWeeksAfterTheLastAsk() {
        let reviews = manager(version: "1.1.0")
        advance(days: 3)
        reviews.didAsk()
        advance(days: 10) // an update came out soon after
        let update = manager(version: "1.1.1")
        XCTAssertFalse(update.shouldAsk(isNewBest: true, isGoldMedal: false, gamesPlayed: 30))
        advance(days: Double(ReviewPromptManager.minimumDaysBetweenAsks))
        XCTAssertTrue(update.shouldAsk(isNewBest: true, isGoldMedal: false, gamesPlayed: 30))
    }

    func testTheFirstLaunchDateSurvivesRelaunches() {
        _ = manager() // day 0: first launch
        advance(days: 3)
        let relaunched = manager() // must not restart the clock
        XCTAssertTrue(relaunched.shouldAsk(isNewBest: true, isGoldMedal: false, gamesPlayed: 10))
    }
}

final class AppStoreLinksTests: XCTestCase {
    func testLinksNeedARealAppID() {
        XCTAssertNil(AppStoreLinks.appPageURL(appID: ""))
        XCTAssertNil(AppStoreLinks.writeReviewURL(appID: "id6471234567"))
        XCTAssertEqual(AppStoreLinks.appPageURL(appID: "6471234567")?.absoluteString,
                       "https://apps.apple.com/app/id6471234567")
        XCTAssertEqual(AppStoreLinks.writeReviewURL(appID: "6471234567")?.absoluteString,
                       "https://apps.apple.com/app/id6471234567?action=write-review")
    }
}
