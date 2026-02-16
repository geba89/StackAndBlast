import SwiftUI

/// Root view that handles navigation between menu and game screens.
struct ContentView: View {
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @State private var selectedMode: GameMode?
    @State private var viewModel = GameViewModel()
    @State private var sessionGameCount = 0
    @State private var showDailyReward = false
    @State private var achievementToast: Achievement?

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

                // Game over overlay (hide during bomb placement mode)
                if viewModel.engine.state == .gameOver && !viewModel.isBombMode {
                    GameOverView(
                        score: viewModel.engine.score,
                        maxCombo: viewModel.engine.maxCombo,
                        totalBlasts: viewModel.engine.totalBlasts,
                        piecesPlaced: viewModel.engine.piecesPlaced,
                        hasContinued: viewModel.engine.hasContinued,
                        gameMode: viewModel.gameMode,
                        hasDoubledScore: viewModel.hasDoubledScore,
                        coinsEarned: viewModel.coinsEarnedThisGame,
                        dailyChallengeTier: viewModel.dailyChallengeTier,
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
                            viewModel.startGame(mode: viewModel.gameMode)
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
                if mode == .dailyChallenge {
                    viewModel.startDailyChallenge()
                } else {
                    viewModel.startGame(mode: mode)
                }
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
