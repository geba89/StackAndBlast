import XCTest
@testable import StackAndBlastCore

/// Rules of the game: placing, blasting, pushing, cascades, scoring.
final class GameEngineTests: XCTestCase {

    private let engine = GameEngine()

    /// Load a board drawn as text (see `BoardSketch`) with the given tray and goal.
    private func load(_ rows: [String], tray: [Piece], goal: Int?, score: Int = 0) {
        engine.startScenario(grid: BoardSketch.grid(rows), tray: tray, minGroupSize: goal, score: score)
    }

    private func piece(_ template: PieceDefinitions.Template, _ color: BlockColor) -> Piece {
        Piece(cells: template.cells, color: color)
    }

    // MARK: - Placement

    func testPlacementScoresOnePointPerCellAndRejectsOverlap() {
        load([". . . .",
              ". B . .",
              ". . . .",
              ". . . ."], tray: [piece(PieceDefinitions.dominoH, .coral)], goal: 5)
        let domino = engine.tray[0]

        XCTAssertFalse(engine.placePiece(domino, at: GridPosition(row: 1, col: 0)).success) // overlaps B
        XCTAssertFalse(engine.placePiece(domino, at: GridPosition(row: 0, col: 3)).success) // off the edge
        XCTAssertTrue(engine.placePiece(domino, at: GridPosition(row: 3, col: 0)).success)
        XCTAssertEqual(engine.score, 2)
        XCTAssertEqual(engine.block(at: GridPosition(row: 3, col: 1))?.color, .coral)
    }

    // MARK: - Blasts

    func testGroupReachingGoalBlasts() {
        load([". . . . .",
              ". . . . .",
              ". B B B .",
              ". . . . .",
              ". . . . ."], tray: [piece(PieceDefinitions.dominoV, .blue)], goal: 5)

        let result = engine.placePiece(engine.tray[0], at: GridPosition(row: 3, col: 2))

        XCTAssertEqual(result.blastEvents.count, 1)
        XCTAssertEqual(result.blastEvents[0].groupSize, 5)
        XCTAssertTrue(engine.grid.joined().allSatisfy { $0 == nil }, "the whole group is cleared")
        // 2 placement points + 5 cells × 20
        XCTAssertEqual(engine.score, 102)
        XCTAssertEqual(result.blastEvents[0].points, 100)
    }

    func testGroupBelowGoalStays() {
        load([". . . .",
              ". B B .",
              ". . . .",
              ". . . ."], tray: [piece(PieceDefinitions.dot, .blue)], goal: 5)

        let result = engine.placePiece(engine.tray[0], at: GridPosition(row: 1, col: 3))
        XCTAssertTrue(result.blastEvents.isEmpty)
        XCTAssertEqual(engine.grid.joined().compactMap { $0 }.count, 3)
    }

    func testBlastPushesNeighborsAndDestroysBlocksPushedOffTheEdge() {
        load([". . . . .",
              ". . G . .",
              "Y B B B .",
              ". . . . .",
              ". . . . ."], tray: [piece(PieceDefinitions.dominoV, .blue)], goal: 5)
        let yellowID = engine.block(at: GridPosition(row: 2, col: 0))!.id
        let greenID = engine.block(at: GridPosition(row: 1, col: 2))!.id

        let result = engine.placePiece(engine.tray[0], at: GridPosition(row: 3, col: 2))
        let pushes = result.blastEvents[0].pushedBlocks

        // Yellow sat at the left edge, so it's pushed off the grid (destroyed)
        XCTAssertEqual(pushes.first { $0.blockID == yellowID }?.to, .some(nil))
        XCTAssertNil(engine.block(at: GridPosition(row: 2, col: 0)))
        // Green is pushed one cell up, away from the blast
        XCTAssertEqual(pushes.first { $0.blockID == greenID }?.to, GridPosition(row: 0, col: 2))
        XCTAssertEqual(engine.block(at: GridPosition(row: 0, col: 2))?.id, greenID)
    }

    func testPushedBlockCanTriggerCascadeWithDoubledPoints() {
        // Blasting the blues pushes the middle green up, completing a row of 4 greens
        load(["G . G G .",
              ". G . . .",
              "B B B . .",
              ". . . . .",
              ". . . . ."], tray: [piece(PieceDefinitions.dot, .blue)], goal: 4)

        let result = engine.placePiece(engine.tray[0], at: GridPosition(row: 2, col: 3))

        XCTAssertEqual(result.blastEvents.map(\.groupColor), [.blue, .green])
        XCTAssertEqual(result.blastEvents.map(\.cascadeLevel), [0, 1])
        XCTAssertEqual(result.blastEvents.map(\.points), [80, 160], "cascade level 1 doubles the points")
        XCTAssertEqual(engine.score, 1 + 80 + 160)
        XCTAssertEqual(engine.maxCombo, 2)
    }

    /// Regression test: the goal used to be re-read after adding placement points, so a
    /// drop at 498 points (goal 10) was judged against goal 11 — a group of exactly 10
    /// silently failed to blast even though the HUD said GOAL 10.
    func testGoalShownWhenDroppingIsTheGoalThatApplies() {
        load([". . . . . . . . .",
              ". . . . . . . . .",
              ". . . . . . . . .",
              ". . . . . . . . .",
              ". . . . . . . . .",
              ". . . . . . . . .",
              ". . . . . . . . .",
              ". . . . . . . . .",
              "B B B B B B . . ."], tray: [piece(PieceDefinitions.lineH4, .blue)], goal: nil, score: 498)
        XCTAssertEqual(engine.currentMinGroupSize, 10)

        let result = engine.placePiece(engine.tray[0], at: GridPosition(row: 7, col: 0))

        XCTAssertEqual(result.blastEvents.first?.groupSize, 10)
        XCTAssertEqual(engine.currentMinGroupSize, 11, "the goal rises for the *next* move")
    }

    // MARK: - Power-ups

    func testColorBombClearsMostCommonColor() {
        load(["P P . .",
              "P . C .",
              ". . . .",
              ". . . ."], tray: [Piece(cells: [GridPosition(row: 0, col: 0)], color: .blue, powerUp: .colorBomb)], goal: 5)

        let result = engine.placePiece(engine.tray[0], at: GridPosition(row: 3, col: 3))

        XCTAssertEqual(result.blastEvents.first?.powerUpSource, .colorBomb)
        XCTAssertEqual(result.blastEvents.first?.groupSize, 3)
        XCTAssertEqual(engine.grid.joined().compactMap { $0 }.map(\.color), [.coral])
        XCTAssertEqual(engine.score, 3 * 20)
    }

    // MARK: - Game over

    func testGameOverWhenRemainingPiecesDontFit() {
        load(["B C",
              "C ."], tray: [piece(PieceDefinitions.dot, .yellow), piece(PieceDefinitions.dominoH, .pink)], goal: 5)

        // Filling the last gap leaves no room for the domino
        let result = engine.placePiece(engine.tray[0], at: GridPosition(row: 1, col: 1))

        XCTAssertTrue(result.gameOver)
        XCTAssertEqual(engine.state, .gameOver)
    }

    func testScenarioWaitsWhenTrayIsUsedUp() {
        load(["B .",
              ". ."], tray: [piece(PieceDefinitions.dot, .coral)], goal: 5)

        let result = engine.placePiece(engine.tray[0], at: GridPosition(row: 1, col: 1))

        XCTAssertFalse(result.gameOver)
        XCTAssertTrue(engine.tray.isEmpty)
        XCTAssertEqual(engine.state, .playing)
    }

    // MARK: - Blast preview

    func testProjectedGroupIncludesConnectedSameColorBlocks() {
        load([". . . . .",
              ". B B . .",
              ". . . C .",
              ". . . . .",
              ". . . . ."], tray: [], goal: 5)

        let blueDomino = piece(PieceDefinitions.dominoV, .blue)
        let group = engine.projectedGroup(for: blueDomino, at: GridPosition(row: 2, col: 1))
        XCTAssertEqual(Set(group), [GridPosition(row: 1, col: 1), GridPosition(row: 1, col: 2),
                                    GridPosition(row: 2, col: 1), GridPosition(row: 3, col: 1)])

        // Different color: only the piece's own cells
        let coralDot = piece(PieceDefinitions.dot, .pink)
        XCTAssertEqual(engine.projectedGroup(for: coralDot, at: GridPosition(row: 0, col: 0)).count, 1)

        // Can't be placed there → no preview
        XCTAssertTrue(engine.projectedGroup(for: blueDomino, at: GridPosition(row: 1, col: 1)).isEmpty)
    }
}
