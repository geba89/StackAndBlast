import XCTest
@testable import StackAndBlastCore

/// The grid size setting must only take effect when a new game starts.
final class GridSizeTests: XCTestCase {

    private var savedGridSize = 9

    override func setUp() {
        super.setUp()
        savedGridSize = SettingsManager.shared.gridSize
    }

    override func tearDown() {
        // Don't leak a changed setting into other tests
        SettingsManager.shared.gridSize = savedGridSize
        super.tearDown()
    }

    /// Regression test: Pause → Settings → pick a bigger grid → resume → place a piece
    /// used to crash with "Index out of range", because the engine read the setting live.
    func testChangingGridSizeMidGameDoesNotAffectCurrentGame() {
        SettingsManager.shared.gridSize = 9
        let engine = GameEngine()
        engine.startNewGame()

        // The player changes the setting from the pause menu
        SettingsManager.shared.gridSize = 12

        // The current game keeps its 9×9 rules...
        XCTAssertEqual(GameConstants.gridSize, 9)
        XCTAssertEqual(engine.grid.count, 9)

        // ...and placing a piece works (this line used to crash)
        let piece = engine.tray.first { !$0.isPowerUp }!
        let result = engine.placePiece(piece, at: GridPosition(row: 0, col: 0))
        XCTAssertTrue(result.success)

        // The next game picks up the new size
        engine.startNewGame()
        XCTAssertEqual(GameConstants.gridSize, 12)
        XCTAssertEqual(engine.grid.count, 12)
        XCTAssertTrue(engine.grid.allSatisfy { $0.count == 12 })
    }

    /// Everyone plays the Daily Challenge on the same board size, so the
    /// "same puzzle worldwide" promise (and its leaderboard) is fair.
    func testDailyChallengeAlwaysUsesStandardGrid() {
        SettingsManager.shared.gridSize = 12
        let engine = GameEngine()
        engine.startDailyChallenge()

        XCTAssertEqual(engine.grid.count, GameConstants.dailyChallengeGridSize)
        XCTAssertEqual(GameConstants.gridSize, GameConstants.dailyChallengeGridSize)
        XCTAssertEqual(engine.currentMinGroupSize, 10) // the 9×9 starting goal
    }
}
