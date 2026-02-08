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

    // MARK: - Actions

    func startGame() {
        isPaused = false
        wantsQuitToMenu = false
        engine.startNewGame()
        scene?.updateGrid(engine.grid)
        scene?.updateTray(engine.tray)
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

        if !result.blastEvents.isEmpty, let preBlastGrid = result.preBlastGrid {
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
}
