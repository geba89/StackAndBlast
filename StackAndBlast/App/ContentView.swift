import SwiftUI

/// Root view that handles navigation between menu and game screens.
struct ContentView: View {
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @State private var selectedMode: GameMode?
    @State private var viewModel = GameViewModel()
    @State private var sessionGameCount = 0
    @State private var showDailyReward = false
    @State private var achievementToast: Achievement?
    @Environment(\.scenePhase) private var scenePhase
    /// Day key of the last daily-reward check, to re-check when the app resumes on a new day.
    @State private var lastDailyRewardCheckDay = ""

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
                        onUseBomb: {
                            viewModel.watchAdForBomb()
                        },
                        onDoubleScore: {
                            viewModel.watchAdForDoubleScore()
                        },
                        onShare: {
                            ShareHelper.shareScoreCard(
                                score: viewModel.engine.score,
                                blasts: viewModel.engine.totalBlasts,
                                maxCombo: viewModel.engine.maxCombo,
                                piecesPlaced: viewModel.engine.piecesPlaced,
                                gameMode: viewModel.gameMode
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

            // Achievement toast overlay
            if let achievement = achievementToast {
                VStack {
                    AchievementToast(achievement: achievement)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                                withAnimation {
                                    achievementToast = nil
                                }
                            }
                        }
                    Spacer()
                }
                .padding(.top, 60)
            }
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
            // Request ATT permission once UI is visible, then start AdMob SDK.
            try? await Task.sleep(for: .seconds(1))
            AdManager.shared.requestTrackingThenConfigure()

            // Load IAP products
            await StoreManager.shared.loadProducts()

            // Authenticate with Game Center for leaderboards
            LeaderboardManager.shared.configure()
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
            checkDailyReward()
        }
        // ...and when the app comes back to the foreground on a new day
        // (iOS can keep the app suspended overnight, so onAppear won't run again)
        .onChange(of: scenePhase) { _, phase in
            if phase == .active && DailyChallengeDate.key() != lastDailyRewardCheckDay {
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
    }

    private func checkDailyReward() {
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
