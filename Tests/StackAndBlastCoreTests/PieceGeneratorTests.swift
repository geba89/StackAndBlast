import XCTest
@testable import StackAndBlastCore

final class PieceGeneratorTests: XCTestCase {

    /// Each size category must keep its designed share (GDD: 10/15/30/30/15%),
    /// no matter how many different shapes the category contains.
    func testCategoryWeightsAreSplitAcrossShapes() {
        for category in PieceDefinitions.Category.allCases {
            let shapes = PieceDefinitions.all.filter { $0.category == category }
            let total = shapes.reduce(0.0) { $0 + PieceDefinitions.spawnWeight(of: $1) }
            XCTAssertEqual(total, category.weight, accuracy: 1e-9, "\(category)")
        }
    }

    /// Regression test: 1-cell pieces used to appear ~1% of the time instead of 10%,
    /// and 4-cell pieces ~56% instead of 30%.
    func testRandomPieceSizesMatchDesignedDistribution() {
        let generator = PieceGenerator()
        generator.setSeed(12345) // seeded → the test is deterministic, never flaky

        let draws = 60_000
        var countsBySize: [Int: Int] = [:]
        for _ in 0..<draws {
            countsBySize[generator.randomTemplate().cells.count, default: 0] += 1
        }

        let expected: [Int: Double] = [1: 0.10, 2: 0.15, 3: 0.30, 4: 0.30, 5: 0.15]
        for (size, share) in expected {
            let observed = Double(countsBySize[size, default: 0]) / Double(draws)
            XCTAssertEqual(observed, share, accuracy: 0.01, "\(size)-cell pieces")
        }
    }

    /// The guaranteed "big" piece in every tray still has 3+ cells.
    func testEveryTrayHasABigPiece() {
        let generator = PieceGenerator()
        generator.setSeed(7)
        for _ in 0..<500 {
            let tray = generator.generateTray()
            XCTAssertEqual(tray.count, GameConstants.piecesPerTray)
            XCTAssertTrue(tray.contains { !$0.isPowerUp && $0.cellCount >= 3 })
        }
    }

    /// Same seed → same trays (shapes, colors, power-ups). This is what makes the
    /// Daily Challenge identical for everyone.
    func testSameSeedProducesSameTrays() {
        let a = PieceGenerator()
        let b = PieceGenerator()
        a.setSeed(2026)
        b.setSeed(2026)
        for _ in 0..<50 {
            let trayA = a.generateTray()
            let trayB = b.generateTray()
            XCTAssertEqual(trayA.map(\.cells), trayB.map(\.cells))
            XCTAssertEqual(trayA.map(\.color), trayB.map(\.color))
            XCTAssertEqual(trayA.map(\.powerUp), trayB.map(\.powerUp))
        }
    }
}

final class DailyChallengeDateTests: XCTestCase {

    private let utc = TimeZone(identifier: "UTC")!

    func testKeyIsGregorianWithAsciiDigits() {
        // 2026-09-24 12:00 UTC
        let date = Date(timeIntervalSince1970: 1_790_251_200)
        XCTAssertEqual(DailyChallengeDate.key(for: date, timeZone: utc), "2026-09-24")
    }

    /// Regression test: the key used to come from a DateFormatter that followed the
    /// device calendar and digits — Thai users got "2569-09-24", Arabic users
    /// "٢٠٢٦-٠٩-٢٤" — so they were served a *different* daily puzzle.
    func testKeyIgnoresDeviceCalendarAndLocale() {
        let date = Date(timeIntervalSince1970: 1_790_251_200)
        let key = DailyChallengeDate.key(for: date, timeZone: utc)
        XCTAssertTrue(key.unicodeScalars.allSatisfy(\.isASCII))
        XCTAssertEqual(
            PieceGenerator.seedForDate(date, timeZone: utc),
            PieceGenerator.seedForKey("2026-09-24")
        )
    }

    /// The daily challenge follows the player's local calendar day (like Wordle).
    func testKeyUsesLocalDay() {
        // 2026-09-24 23:30 UTC is already the 25th in Tokyo
        let date = Date(timeIntervalSince1970: 1_790_292_600)
        XCTAssertEqual(DailyChallengeDate.key(for: date, timeZone: utc), "2026-09-24")
        XCTAssertEqual(DailyChallengeDate.key(for: date, timeZone: TimeZone(identifier: "Asia/Tokyo")!), "2026-09-25")
    }
}
