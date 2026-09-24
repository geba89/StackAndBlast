import XCTest
@testable import StackAndBlastCore

final class UndoTests: XCTestCase {

    private let engine = GameEngine()

    private func load(_ rows: [String], tray: [Piece], goal: Int? = 5, score: Int = 0) {
        engine.startScenario(grid: BoardSketch.grid(rows), tray: tray, minGroupSize: goal, score: score)
    }

    private func piece(_ template: PieceDefinitions.Template, _ color: BlockColor) -> Piece {
        Piece(cells: template.cells, color: color)
    }

    func testNothingToUndoAtStart() {
        engine.startNewGame()
        XCTAssertFalse(engine.canUndo)
        XCTAssertFalse(engine.undoLastMove())
    }

    func testUndoRestoresBoardTrayAndScoreAfterABlast() {
        load([". . . . .",
              ". . G . .",
              "Y B B B .",
              ". . . . .",
              ". . . . ."], tray: [piece(PieceDefinitions.dominoV, .blue), piece(PieceDefinitions.dot, .pink)])
        let gridBefore = engine.grid
        let trayBefore = engine.tray.map(\.id)

        let result = engine.placePiece(engine.tray[0], at: GridPosition(row: 3, col: 2))
        XCTAssertFalse(result.blastEvents.isEmpty, "precondition: the move blasts and pushes")
        XCTAssertTrue(engine.canUndo)

        XCTAssertTrue(engine.undoLastMove())
        XCTAssertEqual(engine.grid, gridBefore, "blasted and pushed blocks are back, same IDs")
        XCTAssertEqual(engine.tray.map(\.id), trayBefore)
        XCTAssertEqual(engine.score, 0)
        XCTAssertEqual(engine.totalBlasts, 0)
        XCTAssertEqual(engine.piecesPlaced, 0)
        XCTAssertEqual(engine.maxCombo, 0)
        XCTAssertFalse(engine.canUndo, "only one move can be undone")
    }

    func testUndoAfterTheMoveThatEndedTheGameResumesPlay() {
        load(["B C",
              "C ."], tray: [piece(PieceDefinitions.dot, .yellow), piece(PieceDefinitions.dominoH, .pink)])
        let result = engine.placePiece(engine.tray[0], at: GridPosition(row: 1, col: 1))
        XCTAssertTrue(result.gameOver)

        XCTAssertTrue(engine.undoLastMove())
        XCTAssertEqual(engine.state, .playing)
        XCTAssertNil(engine.block(at: GridPosition(row: 1, col: 1)))
        XCTAssertEqual(engine.tray.count, 2)
    }

    func testBombsShuffleDoubleScoreAndTimeUpClearTheUndo() {
        let actions: [(String, (GameEngine) -> Void)] = [
            ("coin bomb", { _ = $0.useCoinBomb(at: GridPosition(row: 0, col: 0)) }),
            ("shuffle", { $0.shuffleTray() }),
            ("double score", { $0.addBonusScore(10) }),
            ("time up", { $0.endGame() }),
        ]
        for (name, action) in actions {
            load([". . .",
                  ". . .",
                  ". . ."], tray: [piece(PieceDefinitions.dot, .blue), piece(PieceDefinitions.dot, .green)])
            engine.placePiece(engine.tray[0], at: GridPosition(row: 0, col: 0))
            XCTAssertTrue(engine.canUndo, name)
            action(engine)
            XCTAssertFalse(engine.canUndo, "\(name) must clear the undo")
        }
    }
}

final class DangerTests: XCTestCase {

    private let engine = GameEngine()

    func testCountsEveryPlacementUpToTheLimit() {
        engine.startScenario(grid: BoardSketch.grid([". . .",
                                                     ". . .",
                                                     ". . ."]),
                             tray: [Piece(cells: PieceDefinitions.dominoH.cells, color: .blue)],
                             minGroupSize: 5)
        // A horizontal domino fits 2 ways per row × 3 rows
        XCTAssertEqual(engine.placementOptionCount(limit: 100), 6)
        XCTAssertEqual(engine.placementOptionCount(limit: 4), 4, "stops counting at the limit")
    }

    func testNearlyFullBoardHasFewOptions() {
        engine.startScenario(grid: BoardSketch.grid(["B C Y",
                                                     "C . G",
                                                     "Y G ."]),
                             tray: [Piece(cells: PieceDefinitions.dot.cells, color: .pink),
                                    Piece(cells: PieceDefinitions.dominoH.cells, color: .pink)],
                             minGroupSize: 5)
        XCTAssertEqual(engine.placementOptionCount(limit: 100), 2, "the dot fits in 2 gaps, the domino nowhere")
    }

    func testPowerUpMeansNoDanger() {
        engine.startScenario(grid: BoardSketch.grid(["B C",
                                                     "C Y"]),
                             tray: [Piece(cells: [GridPosition(row: 0, col: 0)], color: .blue, powerUp: .rowBlast)],
                             minGroupSize: 5)
        XCTAssertEqual(engine.placementOptionCount(limit: 7), 7)
    }
}
