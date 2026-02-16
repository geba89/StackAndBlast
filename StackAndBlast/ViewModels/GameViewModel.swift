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

    // MARK: - Double Score

    /// Whether the player has already doubled their score this game.
    var hasDoubledScore: Bool = false

    /// Coins earned in the current game (for display on game over screen).
    var coinsEarnedThisGame: Int = 0

    /// The daily challenge tier achieved (nil if not a daily challenge or not yet over).
    var dailyChallengeTier: DailyChallengeTier?

    // MARK: - Coin Power-Ups

    /// Number of coin bombs used this game (max 1).
    var coinBombsUsed: Int = 0

    /// Number of shuffles used this game (max 3).
    var shufflesUsed: Int = 0

    /// Whether the player is in coin-bomb targeting mode (during gameplay).
    var isCoinBombMode: Bool = false

    /// Whether the coin bomb button should be enabled.
    var canUseCoinBomb: Bool {
        coinBombsUsed < GameConstants.maxCoinBombsPerGame
        && CoinManager.shared.canAfford(GameConstants.coinBombPrice)
        && engine.state == .playing
        && !isAnimating
    }

    /// Whether the shuffle button should be enabled.
    var canUseShuffle: Bool {
        shufflesUsed < GameConstants.maxShufflesPerGame
        && CoinManager.shared.canAfford(GameConstants.coinShufflePrice)
        && engine.state == .playing
        && !isAnimating
        && gameMode != .dailyChallenge // Shuffle breaks deterministic pieces
    }

    // MARK: - Actions

    func startGame(mode: GameMode = .classic) {
        gameMode = mode
        isPaused = false
        wantsQuitToMenu = false
        hasRecordedStats = false
        hasDoubledScore = false
        coinsEarnedThisGame = 0
        dailyChallengeTier = nil
        coinBombsUsed = 0
        shufflesUsed = 0
        isCoinBombMode = false
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

        AnalyticsManager.shared.logGameStart(mode: mode.analyticsName)
    }

    /// Start a Daily Challenge game (60s timed, deterministic pieces).
    func startDailyChallenge() {
        gameMode = .dailyChallenge
        isPaused = false
        wantsQuitToMenu = false
        hasRecordedStats = false
        hasDoubledScore = false
        coinsEarnedThisGame = 0
        dailyChallengeTier = nil
        coinBombsUsed = 0
        shufflesUsed = 0
        isCoinBombMode = false
        engine.startDailyChallenge()
        scene?.updateGrid(engine.grid)
        scene?.updateTray(engine.tray)

        timeRemaining = GameConstants.dailyChallengeDuration
        startBlastRushTimer() // Reuse the same countdown timer

        AnalyticsManager.shared.logGameStart(mode: "daily_challenge")
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
        blastRushTimer?.invalidate()
        blastRushTimer = nil

        // Record stats for the partial game before quitting
        if !hasRecordedStats {
            hasRecordedStats = true
            StatsManager.shared.recordGameTotals(
                score: engine.score,
                blasts: engine.totalBlasts,
                piecesPlaced: engine.piecesPlaced
            )
            StatsManager.shared.updateBests(
                score: engine.score,
                maxCombo: engine.maxCombo
            )
            ScoreManager.shared.submitScore(engine.score, mode: gameMode)
        }

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
            // Combo = total blast events from this single placement
            currentCombo = result.blastEvents.count

            // Show combo overlay when multiple blasts occur from one move
            if currentCombo >= 2 {
                scene?.showComboOverlay(level: currentCombo)
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

    /// Centralized game-over handling: submit score, record stats, earn coins, check achievements.
    private func handleGameOver() {
        AudioManager.shared.playGameOver()
        ScoreManager.shared.submitScore(engine.score, mode: gameMode)

        // Record accumulative totals once per game (prevent double-counting after bomb)
        if !hasRecordedStats {
            StatsManager.shared.recordGameTotals(
                score: engine.score,
                blasts: engine.totalBlasts,
                piecesPlaced: engine.piecesPlaced
            )
        }

        // Always update "best of" records so post-bomb improvements are captured
        StatsManager.shared.updateBests(
            score: engine.score,
            maxCombo: engine.maxCombo
        )
        hasRecordedStats = true

        // Award coins based on score
        let coins = CoinManager.coinsForScore(engine.score)
        CoinManager.shared.earn(coins, source: "gameplay")
        coinsEarnedThisGame = coins

        // Log game over analytics
        AnalyticsManager.shared.logGameOver(
            mode: gameMode.analyticsName,
            score: engine.score,
            blasts: engine.totalBlasts,
            piecesPlaced: engine.piecesPlaced,
            maxCombo: engine.maxCombo
        )
        AnalyticsManager.shared.logCoinsEarned(amount: coins, source: "gameplay")

        // Check achievements
        AchievementManager.shared.checkAchievements()

        // Daily challenge reward
        if gameMode == .dailyChallenge {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            UserDefaults.standard.set(formatter.string(from: Date()), forKey: "lastDailyChallengeDate")

            if let result = DailyChallengeRewardManager.shared.claimReward(score: engine.score) {
                dailyChallengeTier = result.tier
                coinsEarnedThisGame += result.coins
            }
        }
    }

    func cancelDrag() {
        draggedPiece = nil
        hoverPosition = nil
    }

    // MARK: - Bomb Continue

    /// Show a rewarded ad, then activate bomb placement mode on success.
    func watchAdForBomb() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.windows.first?.rootViewController else { return }

        let presentAd = { [weak self] in
            AdManager.shared.showRewardedAd(from: rootVC) { [weak self] success in
                guard let self, success else { return }
                self.isBombMode = true
                AnalyticsManager.shared.logBombAdWatched(score: self.engine.score)
            }
        }

        if AdManager.shared.isRewardedAdReady {
            presentAd()
        } else {
            AdManager.shared.loadBombRewardedAd { ready in
                if ready {
                    presentAd()
                }
            }
        }
    }

    // MARK: - Double Score Ad

    /// Show a rewarded ad to double the player's score.
    func watchAdForDoubleScore() {
        guard !hasDoubledScore else { return }

        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.windows.first?.rootViewController else { return }

        let presentAd = { [weak self] in
            AdManager.shared.showDoubleScoreAd(from: rootVC) { [weak self] success in
                guard let self, success else { return }
                let originalScore = self.engine.score
                self.engine.addBonusScore(originalScore)
                self.hasDoubledScore = true

                // Award extra coins for the bonus score
                let bonusCoins = CoinManager.coinsForScore(originalScore)
                CoinManager.shared.earn(bonusCoins, source: "double_score_ad")
                self.coinsEarnedThisGame += bonusCoins

                AnalyticsManager.shared.logDoubleScoreAdWatched(originalScore: originalScore)
                AnalyticsManager.shared.logCoinsEarned(amount: bonusCoins, source: "double_score_ad")

                // Update high scores with the new doubled score
                StatsManager.shared.updateBests(
                    score: self.engine.score,
                    maxCombo: self.engine.maxCombo
                )
                ScoreManager.shared.submitScore(self.engine.score, mode: self.gameMode)
            }
        }

        if AdManager.shared.isDoubleScoreAdReady {
            presentAd()
        } else {
            AdManager.shared.loadDoubleScoreAd()
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

    // MARK: - Coin Power-Up Actions

    /// Activate coin bomb targeting mode — spend coins, then player taps grid to detonate.
    func activateCoinBomb() {
        guard canUseCoinBomb else { return }
        guard CoinManager.shared.spend(GameConstants.coinBombPrice) else { return }
        coinBombsUsed += 1
        isCoinBombMode = true
        AnalyticsManager.shared.logCoinPowerUpUsed(type: "bomb", price: GameConstants.coinBombPrice)
    }

    /// Place the coin bomb at a grid position during gameplay.
    func placeCoinBomb(at position: GridPosition) {
        guard isCoinBombMode else { return }
        isCoinBombMode = false

        let result = engine.useCoinBomb(at: position)
        guard result.success else { return }

        isAnimating = true
        scene?.isAnimating = true
        scene?.animateBombExplosion(result: result) { [weak self] in
            guard let self else { return }
            self.isAnimating = false
            self.scene?.isAnimating = false
            self.scene?.updateGrid(self.engine.grid)
            self.scene?.updateTray(self.engine.tray)
        }
    }

    /// Spend coins and regenerate tray pieces.
    func useShuffle() {
        guard canUseShuffle else { return }
        guard CoinManager.shared.spend(GameConstants.coinShufflePrice) else { return }
        shufflesUsed += 1
        engine.shuffleTray()
        scene?.updateTray(engine.tray)
        AudioManager.shared.playPlacement()
        HapticManager.shared.playPlacement()
        AnalyticsManager.shared.logCoinPowerUpUsed(type: "shuffle", price: GameConstants.coinShufflePrice)
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
