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

    /// RESTART is offered for every mode except the Daily Challenge (one attempt per day).
    var canRestart: Bool { gameMode != .dailyChallenge }

    // MARK: - Countdown (Blast Rush + Daily Challenge)

    /// Time remaining on the clock (seconds).
    var timeRemaining: TimeInterval = 0

    /// Timer driving the countdown.
    private var blastRushTimer: Timer?

    /// When the countdown last ticked (monotonic clock), so each tick subtracts the
    /// real elapsed time — a `Timer` fires late whenever the main thread is busy.
    private var lastTimerTick: TimeInterval = 0

    // MARK: - Game Over Bookkeeping

    /// Whether the player is in bomb placement mode (after watching ad).
    var isBombMode: Bool = false

    /// Whether game-over stats have been recorded for this session (prevent double-counting).
    private var hasRecordedStats = false

    /// Whether the current ending has been processed. A game can report its end twice
    /// (e.g. the clock runs out while the final blast is still animating).
    private var isGameOverHandled = false

    /// Coins already paid out for this game's score. A bomb continue ends a game twice;
    /// the second game over only tops up to the new total.
    private var coinsAwardedForScore = 0

    /// The day key a Daily Challenge was started on — a run that crosses midnight
    /// still counts for the day whose pieces it used.
    private var dailyChallengeDayKey = ""

    /// Bumped on every new game. Animation callbacks remember the generation they
    /// started in and do nothing if a new game has begun since (e.g. RESTART
    /// pressed from the pause menu while a cascade was still animating).
    private var gameGeneration = 0

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

    /// Start a game in any mode. Every new game — from the menu, PLAY AGAIN or
    /// RESTART — goes through here, so no per-game state can leak between games.
    func startGame(mode: GameMode) {
        resetForNewGame(mode: mode)

        switch mode {
        case .classic:
            engine.startNewGame()
        case .blastRush:
            engine.startNewGame()
            startCountdown(from: GameConstants.blastRushDuration)
        case .dailyChallenge:
            dailyChallengeDayKey = DailyChallengeDate.key()
            engine.startDailyChallenge()
            startCountdown(from: GameConstants.dailyChallengeDuration)
        }

        scene?.updateGrid(engine.grid)
        scene?.updateTray(engine.tray)

        AnalyticsManager.shared.logGameStart(mode: mode.analyticsName)
    }

    /// RESTART from the pause menu: a fresh game in the same mode.
    /// (It used to always start Classic, even from Blast Rush or the Daily Challenge.)
    func restart() {
        guard canRestart else { return }
        recordAbandonedGame()
        startGame(mode: gameMode)
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

    /// Pause automatically when the app leaves the foreground (incoming call, app
    /// switcher, Control Center) so the clock doesn't keep running behind the player's back.
    func pauseIfPlaying() {
        guard engine.state == .playing else { return }
        engine.pause()
        isPaused = true
    }

    func quitToMenu() {
        isPaused = false
        stopCountdown()
        recordAbandonedGame()

        // Quitting uses up today's Daily Challenge. Otherwise players could quit and
        // retry the same (deterministic) pieces until they got a perfect run.
        if gameMode == .dailyChallenge {
            markDailyChallengePlayed()
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

        guard result.success else {
            // E.g. the clock ran out mid-drag — put the faded piece back in the tray
            scene?.updateTray(engine.tray)
            return
        }

        // Audio + haptic feedback for successful placement
        AudioManager.shared.playPlacement()
        HapticManager.shared.playPlacement()

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

            let generation = gameGeneration
            scene?.animateBlastSequence(
                events: result.blastEvents,
                preBlastGrid: preBlastGrid,
                finalGrid: engine.grid
            ) { [weak self] in
                // A new game may have started while this was animating — ignore it then
                guard let self, self.gameGeneration == generation else { return }
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
            if result.gameOver {
                handleGameOver()
            }
        }
    }

    /// Centralized game-over handling: submit score, record stats, earn coins, check achievements.
    private func handleGameOver() {
        guard !isGameOverHandled else { return }
        isGameOverHandled = true
        isCoinBombMode = false
        stopCountdown()

        AudioManager.shared.playGameOver()
        ScoreManager.shared.submitScore(engine.score, mode: gameMode)
        LeaderboardManager.shared.submitScore(engine.score, mode: gameMode)

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
            maxCombo: engine.maxCombo,
            piecesPlaced: engine.piecesPlaced
        )
        hasRecordedStats = true

        // Award coins based on score — after a bomb continue, only the difference
        let coins = CoinManager.coinsToAward(forScore: engine.score, alreadyAwarded: coinsAwardedForScore)
        coinsAwardedForScore += coins
        CoinManager.shared.earn(coins, source: "gameplay")
        coinsEarnedThisGame += coins

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
            markDailyChallengePlayed()

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
        // A doubled score is final — continuing would carry the doubled score into more play
        guard !hasDoubledScore, !engine.hasContinued else { return }
        guard let topVC = AdManager.shared.topViewController() else { return }

        let presentAd = { [weak self] in
            let presentingVC = AdManager.shared.topViewController() ?? topVC
            AdManager.shared.showRewardedAd(from: presentingVC) { [weak self] success in
                guard let self, success else { return }
                self.isBombMode = true
                AnalyticsManager.shared.logBombAdWatched(score: self.engine.score)
            }
        }

        // Only present if the ad was successfully preloaded — don't load on-the-fly
        // to avoid showing test/sample ads when production inventory has no fill.
        guard AdManager.shared.isRewardedAdReady else { return }
        presentAd()
    }

    // MARK: - Double Score Ad

    /// Show a rewarded ad to double the player's score.
    func watchAdForDoubleScore() {
        guard !hasDoubledScore else { return }

        guard let topVC = AdManager.shared.topViewController() else { return }

        let presentAd = { [weak self] in
            let presentingVC = AdManager.shared.topViewController() ?? topVC
            AdManager.shared.showDoubleScoreAd(from: presentingVC) { [weak self] success in
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
                    maxCombo: self.engine.maxCombo,
                    piecesPlaced: self.engine.piecesPlaced
                )
                ScoreManager.shared.submitScore(self.engine.score, mode: self.gameMode)
                LeaderboardManager.shared.submitScore(self.engine.score, mode: self.gameMode)
            }
        }

        // Only present if the ad was successfully preloaded — don't load on-the-fly
        // to avoid showing test/sample ads when production inventory has no fill.
        guard AdManager.shared.isDoubleScoreAdReady else { return }
        presentAd()
    }

    /// Place the bomb at the given grid position and animate the explosion.
    func placeBomb(at position: GridPosition) {
        guard isBombMode else { return }
        isBombMode = false

        let result = engine.useBomb(at: position)
        guard result.success else { return }

        if result.gameResumed {
            // The game is back on, so its next ending must be processed again
            isGameOverHandled = false
        }

        // Animate the bomb explosion
        isAnimating = true
        scene?.isAnimating = true
        let generation = gameGeneration
        scene?.animateBombExplosion(result: result) { [weak self] in
            guard let self, self.gameGeneration == generation else { return }
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

    /// Enter coin-bomb targeting mode — the player then taps the grid to detonate.
    /// Coins are only charged when the bomb goes off, so backing out is free.
    func activateCoinBomb() {
        guard canUseCoinBomb else { return }
        isCoinBombMode = true
    }

    /// Leave targeting mode without using the bomb (tapping the bomb button again).
    func cancelCoinBomb() {
        isCoinBombMode = false
    }

    /// Place the coin bomb at a grid position during gameplay.
    func placeCoinBomb(at position: GridPosition) {
        guard isCoinBombMode else { return }
        isCoinBombMode = false

        // Charge now — previously the coins were taken when the button was tapped,
        // so cancelling (or quitting while targeting) silently burned 100 coins.
        guard engine.state == .playing, !isAnimating,
              CoinManager.shared.spend(GameConstants.coinBombPrice) else { return }
        coinBombsUsed += 1
        AnalyticsManager.shared.logCoinPowerUpUsed(type: "bomb", price: GameConstants.coinBombPrice)

        let result = engine.useCoinBomb(at: position)
        guard result.success else { return }

        isAnimating = true
        scene?.isAnimating = true
        let generation = gameGeneration
        scene?.animateBombExplosion(result: result) { [weak self] in
            guard let self, self.gameGeneration == generation else { return }
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

    // MARK: - Private Helpers

    /// Reset every piece of per-game UI state before a new game starts.
    private func resetForNewGame(mode: GameMode) {
        gameGeneration += 1 // orphan any animation still running from the last game
        scene?.cancelAnimations()
        stopCountdown()

        gameMode = mode
        isPaused = false
        wantsQuitToMenu = false
        isAnimating = false
        currentCombo = 0
        draggedPiece = nil
        hoverPosition = nil
        isBombMode = false
        isCoinBombMode = false
        hasRecordedStats = false
        isGameOverHandled = false
        coinsAwardedForScore = 0
        hasDoubledScore = false
        coinsEarnedThisGame = 0
        dailyChallengeTier = nil
        coinBombsUsed = 0
        shufflesUsed = 0
    }

    /// Record lifetime stats for a game the player walked away from (quit or restart).
    private func recordAbandonedGame() {
        guard !hasRecordedStats else { return }
        hasRecordedStats = true
        StatsManager.shared.recordGameTotals(
            score: engine.score,
            blasts: engine.totalBlasts,
            piecesPlaced: engine.piecesPlaced
        )
        StatsManager.shared.updateBests(
            score: engine.score,
            maxCombo: engine.maxCombo,
            piecesPlaced: engine.piecesPlaced
        )
        ScoreManager.shared.submitScore(engine.score, mode: gameMode)
    }

    /// Remember that today's Daily Challenge was played (the menu shows "DAILY COMPLETED").
    private func markDailyChallengePlayed() {
        UserDefaults.standard.set(dailyChallengeDayKey, forKey: "lastDailyChallengeDate")
    }

    // MARK: - Countdown

    private func startCountdown(from seconds: TimeInterval) {
        timeRemaining = seconds
        lastTimerTick = ProcessInfo.processInfo.systemUptime
        blastRushTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.tickCountdown()
        }
    }

    private func tickCountdown() {
        // Subtract the real time since the last tick, capped so one long stall
        // (e.g. the app being suspended) can't eat the clock in a single tick
        let now = ProcessInfo.processInfo.systemUptime
        let elapsed = min(now - lastTimerTick, 0.25)
        lastTimerTick = now

        // The clock only runs while playing (not when paused or over)
        guard engine.state == .playing else { return }

        timeRemaining -= elapsed
        if timeRemaining <= 0 {
            timeRemaining = 0
            stopCountdown()
            engine.endGame()
            handleGameOver()
        }
    }

    private func stopCountdown() {
        blastRushTimer?.invalidate()
        blastRushTimer = nil
    }

    /// Add bonus time for blasts in Blast Rush mode (GDD: +5s per blast).
    private func addBlastRushTimeBonus(blastCount: Int) {
        guard gameMode == .blastRush else { return }
        timeRemaining += GameConstants.blastRushTimeBonusPerBlast * Double(blastCount)
    }
}
