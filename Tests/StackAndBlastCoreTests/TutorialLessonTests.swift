import XCTest
@testable import StackAndBlastCore

/// Plays every tutorial lesson through the real engine and checks that the board
/// does exactly what the lesson's text promises.
final class TutorialLessonTests: XCTestCase {

    private let lessons = TutorialLesson.all

    /// Load a lesson the way the game does and make the lesson's move.
    private func play(_ lesson: TutorialLesson) -> (engine: GameEngine, result: PlacementResult) {
        let engine = GameEngine()
        engine.startScenario(grid: BoardSketch.grid(lesson.board), tray: [lesson.piece],
                             minGroupSize: TutorialLesson.goal)
        let result = engine.placePiece(engine.tray[0], at: lesson.target)
        return (engine, result)
    }

    private func blocks(of color: BlockColor, in engine: GameEngine) -> Int {
        engine.grid.joined().compactMap { $0 }.filter { $0.color == color }.count
    }

    func testEveryLessonIsWellFormed() {
        XCTAssertEqual(lessons.count, 4)
        for lesson in lessons {
            let grid = BoardSketch.grid(lesson.board)
            XCTAssertEqual(grid.count, 7, lesson.title)
            XCTAssertTrue(grid.allSatisfy { $0.count == 7 }, "\(lesson.title) board must be 7×7")

            // Nothing should blast before the player moves
            let engine = GameEngine()
            engine.startScenario(grid: grid, tray: [lesson.piece], minGroupSize: TutorialLesson.goal)
            XCTAssertTrue(engine.canPlace(lesson.piece, at: lesson.target), "\(lesson.title): target must be free")

            // The move plays out, then the lesson waits for the next one
            let (after, result) = play(lesson)
            XCTAssertTrue(result.success, lesson.title)
            XCTAssertFalse(result.blastEvents.isEmpty, "\(lesson.title) must end with a blast")
            XCTAssertFalse(result.gameOver, lesson.title)
            XCTAssertEqual(after.state, .playing, lesson.title)
            XCTAssertTrue(after.tray.isEmpty, lesson.title)
        }
    }

    func testLesson1MakesABlastOfFiveBlue() {
        let (engine, result) = play(lessons[0])
        XCTAssertEqual(result.blastEvents.count, 1)
        XCTAssertEqual(result.blastEvents[0].groupColor, .blue)
        XCTAssertEqual(result.blastEvents[0].groupSize, 5)
        XCTAssertEqual(blocks(of: .blue, in: engine), 0)
    }

    func testLesson2PushesNeighborsAndOneFallsOffTheEdge() {
        let lesson = lessons[1]
        let startGrid = BoardSketch.grid(lesson.board)
        let (engine, result) = play(lesson)

        let pushes = result.blastEvents[0].pushedBlocks
        XCTAssertGreaterThanOrEqual(pushes.count, 3, "several neighbors get pushed")
        XCTAssertTrue(pushes.contains { $0.to == nil }, "a block is pushed off the edge")
        XCTAssertEqual(blocks(of: .green, in: engine), 0, "the green block at the edge is destroyed")
        // Everything else survived (2 yellow + 1 pink)
        XCTAssertEqual(engine.grid.joined().compactMap { $0 }.count,
                       startGrid.joined().compactMap { $0 }.count - 3 /* purple */ - 1 /* green */)
    }

    func testLesson3TriggersAChainReaction() {
        let (engine, result) = play(lessons[2])
        XCTAssertEqual(result.blastEvents.map(\.groupColor), [.coral, .green])
        XCTAssertEqual(result.blastEvents.map(\.cascadeLevel), [0, 1])
        XCTAssertEqual(result.blastEvents[1].points, 2 * result.blastEvents[0].points,
                       "the chain link scores double (both groups have 5 blocks)")
        XCTAssertEqual(engine.grid.joined().compactMap { $0 }.count, 0, "board is cleared")
    }

    func testLesson4ColorBombClearsEveryPinkBlock() {
        let lesson = lessons[3]
        let pinkBefore = BoardSketch.grid(lesson.board).joined().compactMap { $0 }.filter { $0.color == .pink }.count
        let (engine, result) = play(lesson)

        XCTAssertEqual(result.blastEvents.first?.powerUpSource, .colorBomb)
        XCTAssertEqual(result.blastEvents.first?.groupSize, pinkBefore)
        XCTAssertEqual(blocks(of: .pink, in: engine), 0)
        XCTAssertGreaterThan(engine.grid.joined().compactMap { $0 }.count, 0, "other colors stay")
    }
}
