import XCTest
@testable import StackAndBlastCore

final class DailyChallengeShareTests: XCTestCase {

    func testSummaryShowsMedalScoreComboAndBlastColors() {
        let text = DailyChallengeShare.text(dayKey: "2026-09-24", score: 2450, bestCombo: 3, medal: "🥇",
                                            blastColors: [.blue, .blue, .purple, .pink, .green, .yellow, .blue, .coral, .green])
        let lines = text.components(separatedBy: "\n")
        XCTAssertEqual(lines[0], "Stack & Blast Daily 2026-09-24 🥇")
        XCTAssertTrue(lines[1].hasPrefix("💥 2"), "score line: \(lines[1])")
        XCTAssertTrue(lines[1].hasSuffix(" · best combo ×3"))
        XCTAssertEqual(lines[2], "🟦🟦🟪🟥🟩🟨🟦🟧", "8 squares per line")
        XCTAssertEqual(lines[3], "🟩")
    }

    func testNoComboOrMedalAndLongRunsAreCapped() {
        let text = DailyChallengeShare.text(dayKey: "2026-09-24", score: 90, bestCombo: 1, medal: nil,
                                            blastColors: Array(repeating: .green, count: 30))
        let lines = text.components(separatedBy: "\n")
        XCTAssertEqual(lines[0], "Stack & Blast Daily 2026-09-24")
        XCTAssertEqual(lines[1], "💥 90")
        XCTAssertEqual(lines.count, 2 + 3 + 1, "3 lines of squares, then the overflow line")
        XCTAssertEqual(lines.last, "+6 more blasts")
    }
}
