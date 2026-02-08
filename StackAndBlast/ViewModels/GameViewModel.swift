import Foundation
import Observation

/// Bridges the GameEngine to the view layer (SwiftUI + SpriteKit).
/// Translates user actions (drag-and-drop) into engine calls and exposes
/// observable state for the UI.
@Observable
final class GameViewModel {

    let engine = GameEngine()

    /// Reference to the SpriteKit scene for pushing visual updates.
    weak var scene: GameScene?

    /// The piece currently being dragged, if any.
    var draggedPiece: Piece?

    /// The grid position the dragged piece is hovering over.
    var hoverPosition: GridPosition?

    /// Whether the current hover position is a valid placement.
    var isHoverValid: Bool {
        guard let piece = draggedPiece, let origin = hoverPosition else { return false }
        return engine.canPlace(piece, at: origin)
    }

    /// Whether blast animations are currently playing.
    var isAnimating: Bool = false

    /// Current cascade combo level (for HUD display). 0 = no combo active.
    var currentCombo: Int = 0

    /// Whether the game is paused.
    var isPaused: Bool = false

    /// Whether the user wants to return to the main menu.
    var wantsQuitToMenu: Bool = false

    /// The current game mode.
    var gameMode: GameMode = .classic

    // MARK: - Blast Rush Timer

    /// Time remaining in Blast Rush mode (seconds).
    var timeRemaining: TimeInterval = 0

    /// Timer for Blast Rush countdown.
    private var blastRushTimer: Timer?

    // MARK: - Actions

    func startGame(mode: GameMode = .classic) {
        gameMode = mode
        isPaused = false
        wantsQuitToMenu = false
        engine.startNewGame()
        scene?.updateGrid(engine.grid)
        scene?.updateTray(engine.tray)

        // Start Blast Rush timer if applicable
        blastRushTimer?.invalidate()
        blastRushTimer = nil
        if mode == .blastRush {
            timeRemaining = 90
            startBlastRushTimer()
        }
    }

    func togglePause() {
        if engine.state == .playing {
            engine.pause()
            isPaused = true
        } else if engine.state == .paused {
            engine.resume()
            isPaused = false
        }
    }

    func quitToMenu() {
        isPaused = false
        wantsQuitToMenu = true
        blastRushTimer?.invalidate()
        blastRushTimer = nil
    }

    func beginDrag(piece: Piece) {
        draggedPiece = piece
    }

    func updateHover(position: GridPosition) {
        hoverPosition = position
    }

    func endDrag() {
        defer {
            draggedPiece = nil
            hoverPosition = nil
        }

        guard let piece = draggedPiece, let origin = hoverPosition else { return }

        let result = engine.placePiece(piece, at: origin)

        guard result.success else { return }

        // Audio + haptic feedback for successful placement
        AudioManager.shared.playPlacement()
        HapticManager.shared.playPlacement()

        if result.gameOver && result.blastEvents.isEmpty {
            AudioManager.shared.playGameOver()
            ScoreManager.shared.submitScore(engine.score, mode: gameMode)
        }

        if !result.blastEvents.isEmpty, let preBlastGrid = result.preBlastGrid {
            // Add time bonus in Blast Rush mode
            addBlastRushTimeBonus(blastCount: result.blastEvents.count)

            // Blast occurred — queue animations
            isAnimating = true
            scene?.isAnimating = true
            currentCombo = result.blastEvents.map(\.cascadeLevel).max().map { $0 + 1 } ?? 0

            scene?.animateBlastSequence(
                events: result.blastEvents,
                preBlastGrid: preBlastGrid,
                finalGrid: engine.grid
            ) { [weak self] in
                guard let self else { return }
                self.isAnimating = false
                self.scene?.isAnimating = false
                self.currentCombo = 0
                self.scene?.updateTray(self.engine.tray)
                if result.gameOver {
                    AudioManager.shared.playGameOver()
                    ScoreManager.shared.submitScore(self.engine.score, mode: self.gameMode)
                }
            }
        } else {
            // No blast — just update the grid and tray immediately
            scene?.updateGrid(engine.grid)
            scene?.updateTray(engine.tray)
        }
    }

    func cancelDrag() {
        draggedPiece = nil
        hoverPosition = nil
    }

    // MARK: - Blast Rush Timer

    private func startBlastRushTimer() {
        blastRushTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self else { return }
            guard self.engine.state == .playing else { return }

            self.timeRemaining -= 0.1
            if self.timeRemaining <= 0 {
                self.timeRemaining = 0
                self.blastRushTimer?.invalidate()
                self.blastRushTimer = nil
                self.engine.endGame()
                AudioManager.shared.playGameOver()
                ScoreManager.shared.submitScore(self.engine.score, mode: .blastRush)
            }
        }
    }

    /// Add bonus time for blasts in Blast Rush mode (GDD: +5s per blast).
    private func addBlastRushTimeBonus(blastCount: Int) {
        guard gameMode == .blastRush else { return }
        timeRemaining += 5.0 * Double(blastCount)
    }
}
