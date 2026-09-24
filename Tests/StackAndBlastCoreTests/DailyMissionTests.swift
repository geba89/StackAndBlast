import XCTest
@testable import StackAndBlastCore

final class DailyMissionTests: XCTestCase {

    func testSameDayGivesSameMissionsAndDaysVary() {
        XCTAssertEqual(DailyMission.missions(forDay: "2026-09-24"), DailyMission.missions(forDay: "2026-09-24"))

        var distinctSets = Set<String>()
        for day in 1...30 {
            let key = "2026-10-" + (day < 10 ? "0\(day)" : "\(day)")
            let missions = DailyMission.missions(forDay: key)
            XCTAssertEqual(missions.count, 3)
            XCTAssertEqual(missions.map(\.reward), [30, 50, 80], "easy, medium, hard")
            XCTAssertEqual(Set(missions.map(\.kind.family)).count, 3, "\(key): no kind twice")
            distinctSets.insert(missions.map(\.title).joined(separator: "|"))
        }
        XCTAssertGreaterThan(distinctSets.count, 10, "missions should change from day to day")
    }

    func testCountingMissionsOnlyCountMatchingEvents() {
        let blue = DailyMission(kind: .blastColor(.blue), target: 3, reward: 30)
        XCTAssertEqual(blue.progress(after: .blast(color: .blue, size: 10), from: 0), 1)
        XCTAssertEqual(blue.progress(after: .blast(color: .green, size: 10), from: 1), 1)
        XCTAssertEqual(blue.progress(after: .piecePlaced, from: 1), 1)
        XCTAssertEqual(blue.progress(after: .blast(color: .blue, size: 10), from: 3), 3, "capped at target")

        let rush = DailyMission(kind: .playBlastRush, target: 1, reward: 30)
        XCTAssertEqual(rush.progress(after: .gameFinished(.classic), from: 0), 0)
        XCTAssertEqual(rush.progress(after: .gameFinished(.blastRush), from: 0), 1)
    }

    func testReachAValueMissionsKeepTheBest() {
        let score = DailyMission(kind: .score, target: 1_500, reward: 50)
        XCTAssertEqual(score.progress(after: .score(900), from: 0), 900)
        XCTAssertEqual(score.progress(after: .score(400), from: 900), 900, "a new game's lower score doesn't reduce it")
        XCTAssertEqual(score.progress(after: .score(4_000), from: 900), 1_500)

        let big = DailyMission(kind: .bigBlast, target: 14, reward: 80)
        XCTAssertEqual(big.progress(after: .blast(color: .pink, size: 11), from: 0), 11)
        XCTAssertEqual(big.progress(after: .blast(color: .pink, size: 15), from: 11), 14)
    }

    func testTitles() {
        XCTAssertEqual(DailyMission(kind: .blastColor(.blue), target: 3, reward: 30).title, "Blast 3 blue groups")
        XCTAssertEqual(DailyMission(kind: .powerUps, target: 1, reward: 30).title, "Use a power-up")
        XCTAssertEqual(DailyMission(kind: .combo, target: 3, reward: 80).title, "Get a ×3 combo in one move")
    }
}

final class MissionManagerTests: XCTestCase {

    private var defaults: UserDefaults!
    private var suiteName = ""
    private var day = "2026-09-24"
    private var payouts: [(Int, String)] = []

    override func setUp() {
        super.setUp()
        suiteName = "MissionManagerTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        day = "2026-09-24"
        payouts = []
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    private func makeManager() -> MissionManager {
        MissionManager(defaults: defaults, today: { [unowned self] in self.day },
                       award: { [unowned self] amount, source in self.payouts.append((amount, source)) })
    }

    /// Events that complete every possible mission kind.
    private func everything() -> [MissionEvent] {
        var events: [MissionEvent] = []
        for color in BlockColor.allCases {
            events += Array(repeating: .blast(color: color, size: 20), count: 5)
        }
        events += Array(repeating: .piecePlaced, count: 130)
        events += Array(repeating: .powerUpUsed, count: 3)
        events += [.combo(5), .score(10_000), .gameFinished(.blastRush), .gameFinished(.dailyChallenge)]
        return events
    }

    func testCompletingMissionsPaysEachOnceThenTheBonus() {
        let manager = makeManager()
        everything().forEach(manager.record)

        XCTAssertEqual(manager.completedCount, 3)
        XCTAssertTrue(manager.bonusAwarded)
        let rewards = manager.missions.map(\.reward)
        XCTAssertEqual(payouts.filter { $0.1 == "mission" }.map { $0.0 }.sorted(), rewards.sorted())
        XCTAssertEqual(payouts.filter { $0.1 == "mission_bonus" }.map { $0.0 }, [MissionManager.allCompleteBonus])
        XCTAssertNotNil(manager.recentlyCompleted)

        // Playing on doesn't pay again
        let paid = payouts.count
        everything().forEach(manager.record)
        XCTAssertEqual(payouts.count, paid)
    }

    func testProgressSurvivesRestartAndResetsOnANewDay() {
        let first = makeManager()
        first.record(.gameFinished(.blastRush))
        first.record(.score(2_000))
        let saved = first.progress

        // App relaunch on the same day: progress restored
        XCTAssertEqual(makeManager().progress, saved)

        // Next day: fresh missions, no progress
        day = "2026-09-25"
        first.refreshIfNewDay()
        XCTAssertEqual(first.dayKey, "2026-09-25")
        XCTAssertEqual(first.missions, DailyMission.missions(forDay: "2026-09-25"))
        XCTAssertEqual(first.progress, [0, 0, 0])
        XCTAssertFalse(first.bonusAwarded)
        XCTAssertEqual(makeManager().progress, [0, 0, 0])
    }
}
