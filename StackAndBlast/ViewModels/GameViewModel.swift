import Foundation
import Observation
import UIKit

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

    // MARK: - Bomb Mode

    /// Whether the player is in bomb placement mode (after watching ad).
    var isBombMode: Bool = false

    /// Whether game-over stats have been recorded for this session (prevent double-counting).
    private var hasRecordedStats = false

    // MARK: - Actions

    func startGame(mode: GameMode = .classic) {
        gameMode = mode
        isPaused = false
        wantsQuitToMenu = false
        hasRecordedStats = false
        engine.startNewGame()
        scene?.updateGrid(engine.grid)
        scene?.updateTray(engine.tray)

        // Start timers if applicable
        blastRushTimer?.invalidate()
        blastRushTimer = nil
        if mode == .blastRush {
            timeRemaining = 90
            startBlastRushTimer()
        }
    }

    /// Start a Daily Challenge game (60s timed, deterministic pieces).
    func startDailyChallenge() {
        gameMode = .dailyChallenge
        isPaused = false
        wantsQuitToMenu = false
        hasRecordedStats = false
        engine.startDailyChallenge()
        scene?.updateGrid(engine.grid)
        scene?.updateTray(engine.tray)

        timeRemaining = GameConstants.dailyChallengeDuration
        startBlastRushTimer() // Reuse the same countdown timer
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
            handleGameOver()
        }

        if !result.blastEvents.isEmpty, let preBlastGrid = result.preBlastGrid {
            // Add time bonus in Blast Rush mode
            addBlastRushTimeBonus(blastCount: result.blastEvents.count)

            // Blast occurred — queue animations
            isAnimating = true
            scene?.isAnimating = true
            currentCombo = result.blastEvents.map(\.cascadeLevel).max().map { $0 + 1 } ?? 0

            // Show combo overlay on the grid for cascade level 2+
            let maxLevel = (result.blastEvents.map(\.cascadeLevel).max() ?? 0) + 1
            if maxLevel >= 2 {
                scene?.showComboOverlay(level: maxLevel)
            }

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
                    self.handleGameOver()
                }
            }
        } else {
            // No blast — just update the grid and tray immediately
            scene?.updateGrid(engine.grid)
            scene?.updateTray(engine.tray)
        }
    }

    /// Centralized game-over handling: submit score, record stats, play sound, mark daily as done.
    private func handleGameOver() {
        AudioManager.shared.playGameOver()
        ScoreManager.shared.submitScore(engine.score, mode: gameMode)

        // Record lifetime stats (once per game)
        if !hasRecordedStats {
            hasRecordedStats = true
            StatsManager.shared.recordGameEnd(
                score: engine.score,
                blasts: engine.totalBlasts,
                piecesPlaced: engine.piecesPlaced,
                maxCombo: engine.maxCombo
            )
        }

        // Mark daily challenge as completed for today
        if gameMode == .dailyChallenge {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            UserDefaults.standard.set(formatter.string(from: Date()), forKey: "lastDailyChallengeDate")
        }
    }

    func cancelDrag() {
        draggedPiece = nil
        hoverPosition = nil
    }

    // MARK: - Bomb Continue

    /// Show a rewarded ad, then activate bomb placement mode on success.
    /// If no ad is loaded yet, tries to load one first.
    func watchAdForBomb() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.windows.first?.rootViewController else { return }

        let presentAd = { [weak self] in
            AdManager.shared.showRewardedAd(from: rootVC) { [weak self] success in
                guard let self, success else { return }
                self.isBombMode = true
            }
        }

        if AdManager.shared.isRewardedAdReady {
            presentAd()
        } else {
            // Ad not loaded yet — try loading, then present when ready
            AdManager.shared.loadRewardedAd { ready in
                if ready {
                    presentAd()
                }
            }
        }
    }

    /// Place the bomb at the given grid position and animate the explosion.
    func placeBomb(at position: GridPosition) {
        guard isBombMode else { return }
        isBombMode = false

        let result = engine.useBomb(at: position)
        guard result.success else { return }

        // Animate the bomb explosion
        isAnimating = true
        scene?.isAnimating = true
        scene?.animateBombExplosion(result: result) { [weak self] in
            guard let self else { return }
            self.isAnimating = false
            self.scene?.isAnimating = false
            self.scene?.updateGrid(self.engine.grid)
            self.scene?.updateTray(self.engine.tray)

            if !result.gameResumed {
                // Board still too full — game stays over
                AudioManager.shared.playGameOver()
            }
        }
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
                self.handleGameOver()
            }
        }
    }

    /// Add bonus time for blasts in Blast Rush mode (GDD: +5s per blast).
    private func addBlastRushTimeBonus(blastCount: Int) {
        guard gameMode == .blastRush else { return }
        timeRemaining += 5.0 * Double(blastCount)
    }
}
