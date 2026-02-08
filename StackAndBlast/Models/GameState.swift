import Foundation

/// The current state of the game.
enum GameState {
    /// Main menu, no active game.
    case menu

    /// Active gameplay — player is placing pieces.
    case playing

    /// A blast sequence is resolving (animations in progress).
    case blasting

    /// Game over — no valid placements remaining.
    case gameOver

    /// Game is paused.
    case paused
}
