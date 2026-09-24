import SwiftUI

/// Root view that handles navigation between menu and game screens.
struct ContentView: View {
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @State private var selectedMode: GameMode?
    @State private var viewModel = GameViewModel()
    @State private var sessionGameCount = 0
    @State private var showDailyReward = false
    @State private var achievementToast: Achievement?
    @State private var missionToast: DailyMission?
    @Environment(\.scenePhase) private var scenePhase
    /// Day key of the last daily-reward check, to re-check when the app resumes on a new day.
    @State private var lastDailyRewardCheckDay = ""

    /// Whether this launch is a CI screenshot run (always false in Release builds).
    private var isScreenshotRun: Bool {
        #if DEBUG
        return ScreenshotScenario.current != nil
        #else
        return false
        #endif
    }

    var body: some View {
        ZStack {
            if !hasSeenOnboarding {
                OnboardingView {
                    withAnimation {
                        hasSeenOnboarding = true
                    }
                }
                .transition(.opacity)
            } else if selectedMode != nil {
                // Active game
                GameView(viewModel: viewModel)
                    .transition(.opacity)

                // Game over overlay — hidden during bomb placement, and held back until the
                // final blast animation has played (the engine reports game over instantly)
                if viewModel.engine.state == .gameOver && !viewModel.isBombMode && !viewModel.isAnimating {
                    GameOverView(
                        score: viewModel.engine.score,
                        bestScore: max(ScoreManager.shared.highScore(for: viewModel.gameMode), viewModel.engine.score),
                        isNewBest: viewModel.isNewBest,
                        maxCombo: viewModel.engine.maxCombo,
                        totalBlasts: viewModel.engine.totalBlasts,
                        piecesPlaced: viewModel.engine.piecesPlaced,
                        hasContinued: viewModel.engine.hasContinued,
                        gameMode: viewModel.gameMode,
                        hasDoubledScore: viewModel.hasDoubledScore,
                        coinsEarned: viewModel.coinsEarnedThisGame,
                        dailyChallengeTier: viewModel.dailyChallengeTier,
                        playAgainTitle: viewModel.gameMode == .dailyChallenge ? "PLAY CLASSIC" : "PLAY AGAIN",
                        canUndo: viewModel.canUseUndo,
                        onUseBomb: {
                            viewModel.watchAdForBomb()
                        },
                        onDoubleScore: {
                            viewModel.watchAdForDoubleScore()
                        },
                        onUndo: {
                            viewModel.useUndo()
                        },
                        onShare: {
                            ShareHelper.shareScoreCard(
                                score: viewModel.engine.score,
                                blasts: viewModel.engine.totalBlasts,
                                maxCombo: viewModel.engine.maxCombo,
                                piecesPlaced: viewModel.engine.piecesPlaced,
                                gameMode: viewModel.gameMode,
                                dailySummary: viewModel.dailyShareText
                            )
                        },
                        onPlayAgain: {
                            sessionGameCount += 1
                            if viewModel.gameMode == .dailyChallenge {
                                // One daily per day: "playing again" used to start a random,
                                // untimed game that still posted to the daily leaderboard.
                                // Switching the mode starts Classic via onChange below.
                                selectedMode = .classic
                            } else {
                                viewModel.startGame(mode: viewModel.gameMode)
                            }
                        },
                        onMainMenu: {
                            sessionGameCount += 1
                            // Show interstitial before returning to menu
                            AdManager.shared.showInterstitialIfNeeded(sessionGameCount: sessionGameCount) {
                                DispatchQueue.main.async {
                                    withAnimation {
                                        selectedMode = nil
                                    }
                                }
                            }
                        }
                    )
                    .transition(.opacity)
                }
            } else {
                // Main menu
                MenuView(selectedMode: $selectedMode)
                    .transition(.opacity)
            }

            // Toasts: unlocked achievements and completed missions (stacked if both appear).
            // Purely informational, so touches pass through to the game underneath.
            VStack(spacing: 8) {
                if let achievement = achievementToast {
                    AchievementToast(achievement: achievement)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                                withAnimation {
                                    achievementToast = nil
                                }
                            }
                        }
                }
                if let mission = missionToast {
                    MissionToast(mission: mission)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                                withAnimation {
                                    missionToast = nil
                                }
                            }
                        }
                }
                Spacer()
            }
            .padding(.top, 60)
            .allowsHitTesting(false)
        }
        .animation(.easeInOut(duration: 0.3), value: selectedMode)
        .preferredColorScheme(.dark)
        .onChange(of: selectedMode) { _, newMode in
            if let mode = newMode {
                viewModel.startGame(mode: mode)
            } else {
                // Returned to menu — check daily reward
                checkDailyReward()
            }
        }
        .task {
            // Screenshot runs skip ads, tracking and Game Center prompts
            guard !isScreenshotRun else { return }

            // Request ATT permission once UI is visible, then start AdMob SDK.
            try? await Task.sleep(for: .seconds(1))
            AdManager.shared.requestTrackingThenConfigure()

            // Load IAP products
            await StoreManager.shared.loadProducts()

            // Authenticate with Game Center for leaderboards
            LeaderboardManager.shared.configure()
        }
        // Tutorial finished or skipped: straight into a real game
        // (changing the mode starts Classic via onChange(of: selectedMode) above)
        .onChange(of: viewModel.tutorialFinished) { _, finished in
            if finished {
                viewModel.tutorialFinished = false
                selectedMode = .classic
            }
        }
        .onChange(of: viewModel.wantsQuitToMenu) { _, wantsQuit in
            if wantsQuit {
                sessionGameCount += 1
                AdManager.shared.showInterstitialIfNeeded(sessionGameCount: sessionGameCount) {
                    DispatchQueue.main.async {
                        withAnimation {
                            selectedMode = nil
                        }
                        viewModel.wantsQuitToMenu = false
                    }
                }
            }
        }
        // Show daily reward popup on first appear
        .onAppear {
            #if DEBUG
            if let scenario = ScreenshotScenario.current {
                hasSeenOnboarding = true
                stageScreenshot(scenario)
                return
            }
            #endif
            checkDailyReward()
        }
        // ...and when the app comes back to the foreground on a new day
        // (iOS can keep the app suspended overnight, so onAppear won't run again)
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            MissionManager.shared.refreshIfNewDay()
            if DailyChallengeDate.key() != lastDailyRewardCheckDay {
                checkDailyReward()
            }
        }
        .sheet(isPresented: $showDailyReward) {
            DailyRewardPopupView()
        }
        // Watch for new achievement unlocks
        .onChange(of: AchievementManager.shared.recentlyUnlocked?.id) { _, newID in
            if newID != nil {
                withAnimation {
                    achievementToast = AchievementManager.shared.recentlyUnlocked
                }
                AchievementManager.shared.recentlyUnlocked = nil
            }
        }
        // ...and for completed daily missions
        .onChange(of: MissionManager.shared.recentlyCompleted) { _, mission in
            if let mission {
                withAnimation {
                    missionToast = mission
                }
                MissionManager.shared.recentlyCompleted = nil
            }
        }
    }

    #if DEBUG
    /// Set up the screen a CI screenshot scenario asks for (see `ScreenshotScenario`).
    private func stageScreenshot(_ scenario: String) {
        switch scenario {
        case "tutorial":
            selectedMode = .tutorial
        case "classic":
            selectedMode = .classic
        case "board", "gameover":
            if scenario == "gameover" {
                // A previous best to beat (→ NEW BEST) and coins to pay for UNDO
                ScoreManager.shared.submitScore(2_980, mode: .classic)
                CoinManager.shared.earn(300, source: "screenshots")
            }
            selectedMode = .classic
            // Give the game screen a moment to appear, then swap in the hand-made board
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                viewModel.stageScreenshot(scenario)
            }
        case "missions":
            // Some progress to show: one mission done, two under way.
            // (MenuView opens the missions sheet in this scenario.)
            let missions = MissionManager.shared
            for _ in 0..<14 { missions.record(.piecePlaced) }
            for color in [BlockColor.blue, .coral, .green, .blue] {
                missions.record(.blast(color: color, size: 11))
            }
            missions.record(.combo(2))
            missions.record(.score(1_250))
        default:
            break // "menu"
        }
    }
    #endif

    private func checkDailyReward() {
        guard !isScreenshotRun else { return }
        lastDailyRewardCheckDay = DailyChallengeDate.key()
        // The app may have been suspended for days — make sure the popup shows the right day
        StreakManager.shared.resetStreakIfDayWasMissed()
        if hasSeenOnboarding && selectedMode == nil && !StreakManager.shared.hasClaimedToday {
            // Small delay to let the view settle
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                showDailyReward = true
            }
        }
    }
}

// MARK: - CI Screenshots

#if DEBUG
/// CI screenshots only: launching with the environment variable SCREENSHOT_SCENARIO
/// (menu, missions, tutorial, classic, board, gameover) jumps straight to that screen,
/// with some staged content, and skips onboarding, ads, sign-in prompts and popups.
/// Not compiled into Release (TestFlight / App Store) builds.
/// See .github/ci/screenshots.sh.
enum ScreenshotScenario {
    static let current = ProcessInfo.processInfo.environment["SCREENSHOT_SCENARIO"]
}
#endif

// MARK: - Mission Toast

/// "Mission complete!" banner, styled like the achievement toast.
private struct MissionToast: View {
    let mission: DailyMission

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.title2)
                .foregroundStyle(Color(red: 0.0, green: 0.722, blue: 0.580))

            VStack(alignment: .leading, spacing: 2) {
                Text("Mission complete!")
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(.gray)
                Text(mission.title)
                    .font(.system(.subheadline, design: .rounded))
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .lineLimit(2)
            }

            Spacer()

            HStack(spacing: 4) {
                Image(systemName: "bitcoinsign.circle.fill")
                    .foregroundStyle(.yellow)
                Text("+\(mission.reward)")
                    .font(.system(.subheadline, design: .rounded))
                    .fontWeight(.bold)
                    .foregroundStyle(.yellow)
            }
        }
        .padding(16)
        .frame(maxWidth: 400)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(red: 0.118, green: 0.153, blue: 0.180))
                .shadow(color: .black.opacity(0.5), radius: 10)
        )
        .padding(.horizontal, 20)
    }
}

// MARK: - Achievement Toast

private struct AchievementToast: View {
    let achievement: Achievement

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: achievement.icon)
                .font(.title2)
                .foregroundStyle(Color(red: 0.882, green: 0.439, blue: 0.333))

            VStack(alignment: .leading, spacing: 2) {
                Text("Achievement Unlocked!")
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(.gray)
                Text(achievement.name)
                    .font(.system(.headline, design: .rounded))
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
            }

            Spacer()

            HStack(spacing: 4) {
                Image(systemName: "bitcoinsign.circle.fill")
                    .foregroundStyle(.yellow)
                Text("+\(achievement.coinReward)")
                    .font(.system(.subheadline, design: .rounded))
                    .fontWeight(.bold)
                    .foregroundStyle(.yellow)
            }
        }
        .padding(16)
        .frame(maxWidth: 400)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(red: 0.118, green: 0.153, blue: 0.180))
                .shadow(color: .black.opacity(0.5), radius: 10)
        )
        .padding(.horizontal, 20)
    }
}
