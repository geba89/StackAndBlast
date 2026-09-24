import XCTest
@testable import StackAndBlastCore

final class CoinManagerTests: XCTestCase {

    func testFirstGameOverAwardsCoinsForScore() {
        XCTAssertEqual(CoinManager.coinsToAward(forScore: 1500, alreadyAwarded: 0), 50)
    }

    /// Regression test: after a bomb continue the second game over paid the full
    /// amount again (50 + 75), instead of topping up to the new total (75).
    func testSecondGameOverOnlyTopsUp() {
        let first = CoinManager.coinsToAward(forScore: 1500, alreadyAwarded: 0)
        let second = CoinManager.coinsToAward(forScore: 2500, alreadyAwarded: first)
        XCTAssertEqual(first + second, CoinManager.coinsForScore(2500))
    }

    func testNoCoinsWhenScoreTierDidNotImprove() {
        XCTAssertEqual(CoinManager.coinsToAward(forScore: 1600, alreadyAwarded: 50), 0)
    }
}
