import SwiftUI
import UIKit

/// Main menu screen with game mode selection, coin balance, and feature buttons.
struct MenuView: View {
    @Binding var selectedMode: GameMode?

    @State private var showSettings = false
    @State private var showStats = false
    @State private var showAchievements = false
    @State private var showStore = false
    @State private var showMissions = false

    /// Hold a reference so SwiftUI's Observation tracks mission progress.
    private let missions = MissionManager.shared
    @AppStorage("lastDailyChallengeDate") private var lastDailyChallengeDate = ""
    @AppStorage("lastDailyBonusDate") private var lastDailyBonusDate = ""
    @AppStorage("hasCompletedTutorial") private var hasCompletedTutorial = false

    /// Hold reference so SwiftUI's Observation framework can track property changes.
    private let networkMonitor = NetworkMonitor.shared

    /// Whether today's daily challenge has already been completed.
    private var isDailyChallengeCompleted: Bool {
        lastDailyChallengeDate == DailyChallengeDate.key()
    }

    /// Whether the daily bonus ad has been watched today.
    private var hasDailyBonusToday: Bool {
        lastDailyBonusDate == DailyChallengeDate.key()
    }

    /// Best Classic score, shown under the logo.
    private var bestScore: Int { ScoreManager.shared.highScore(for: .classic) }

    /// Brand-new players get the tutorial when they tap PLAY.
    private var isNewPlayer: Bool {
        !hasCompletedTutorial && StatsManager.shared.totalGamesPlayed == 0
    }

    var body: some View {
        ZStack {
            CandyBackground()
            FloatingCandyBlocks()

            VStack(spacing: 0) {
                // Top bar: coin balance + icon buttons
                HStack(spacing: 10) {
                    HStack(spacing: 6) {
                        CoinIcon(size: 20)
                        Text("\(CoinManager.shared.balance)")
                            .font(.system(size: 17, weight: .black, design: .rounded))
                            .foregroundStyle(Color.candyGold)
                    }
                    .candyChip()
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(CoinManager.shared.balance) coins")

                    Spacer()

                    // Leaderboard (Game Center)
                    if LeaderboardManager.shared.isAuthenticated {
                        CandyIconButton(systemName: "list.number", size: 38, label: "Leaderboards") {
                            LeaderboardManager.shared.showLeaderboard()
                        }
                    }
                    CandyIconButton(systemName: "trophy.fill", size: 38, label: "Achievements") {
                        showAchievements = true
                    }
                    CandyIconButton(systemName: "cart.fill", size: 38, label: "Store") {
                        showStore = true
                    }
                    CandyIconButton(systemName: "chart.bar.fill", size: 38, label: "Stats") {
                        showStats = true
                    }
                    CandyIconButton(systemName: "gearshape.fill", size: 38, label: "Settings") {
                        showSettings = true
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)

                // Centered content — constrained on iPad
                VStack(spacing: 0) {
                    Spacer(minLength: 8)

                    // Logo: gets its space first, and shrinks on small screens
                    CandyLogo()
                        .frame(maxWidth: 400)
                        .layoutPriority(1)

                    // Best score + streak
                    HStack(spacing: 10) {
                        if bestScore > 0 {
                            HStack(spacing: 6) {
                                Image(systemName: "crown.fill")
                                    .font(.system(size: 13, weight: .bold))
                                Text("BEST")
                                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                                    .tracking(0.6)
                                Text(bestScore.grouped)
                                    .font(.system(size: 16, weight: .black, design: .rounded))
                                    .foregroundStyle(.white)
                            }
                            .foregroundStyle(Color(hex: 0xFFD76A))
                            .candyChip()
                        }
                        if StreakManager.shared.currentStreak > 0 {
                            HStack(spacing: 6) {
                                Image(systemName: "flame.fill")
                                Text("\(StreakManager.shared.currentStreak)-day streak")
                            }
                            .font(.system(size: 14, weight: .heavy, design: .rounded))
                            .foregroundStyle(Color(hex: 0xFF9A3C))
                            .candyChip()
                        }
                    }
                    .padding(.top, 10)

                    Spacer(minLength: 14)

                    // Offline banner — gameplay still works, only ads are unavailable
                    if !networkMonitor.isConnected {
                        HStack(spacing: 8) {
                            Image(systemName: "wifi.slash")
                            Text("Offline mode — ads unavailable")
                        }
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .candyChip()
                        .padding(.bottom, 12)
                    }

                    // Menu buttons
                    VStack(spacing: 12) {
                        Button {
                            // Brand-new players learn by doing first; everyone else goes straight in
                            selectedMode = isNewPlayer ? .tutorial : .classic
                        } label: {
                            CandyMenuLabel(icon: "play.fill", title: "PLAY",
                                           subtitle: isNewPlayer ? "Quick lesson first" : "Classic · endless",
                                           big: true)
                        }
                        .buttonStyle(ChunkyButtonStyle(colors: .green))

                        // Daily Challenge — once a day
                        Button {
                            if !isDailyChallengeCompleted {
                                selectedMode = .dailyChallenge
                            }
                        } label: {
                            CandyMenuLabel(icon: isDailyChallengeCompleted ? "checkmark.seal.fill" : "calendar",
                                           title: isDailyChallengeCompleted ? "DAILY DONE" : "DAILY CHALLENGE",
                                           subtitle: isDailyChallengeCompleted
                                               ? "A new board tomorrow"
                                               : "Today's board · \(Int(GameConstants.dailyChallengeDuration)) seconds",
                                           tag: isDailyChallengeCompleted ? nil : "NEW")
                        }
                        .buttonStyle(ChunkyButtonStyle(colors: .blue))
                        .disabled(isDailyChallengeCompleted)

                        Button {
                            selectedMode = .blastRush
                        } label: {
                            CandyMenuLabel(icon: "bolt.fill", title: "BLAST RUSH",
                                           subtitle: "\(Int(GameConstants.blastRushDuration)) seconds · "
                                               + "+\(Int(GameConstants.blastRushTimeBonusPerBlast))s per blast")
                        }
                        .buttonStyle(ChunkyButtonStyle(colors: .orange))

                        // Daily missions + replayable tutorial, side by side to save space
                        HStack(spacing: 12) {
                            SecondaryMenuButton(
                                icon: missions.completedCount == missions.missions.count
                                    ? "checkmark.seal.fill" : "checklist",
                                title: "MISSIONS",
                                badge: "\(missions.completedCount)/\(missions.missions.count)"
                            ) {
                                showMissions = true
                            }
                            SecondaryMenuButton(icon: "questionmark.circle.fill", title: "HOW TO PLAY", badge: nil) {
                                selectedMode = .tutorial
                            }
                        }

                        // Daily bonus ad button — only shown when an ad is actually loaded
                        if networkMonitor.isConnected && !hasDailyBonusToday && AdManager.shared.isRewardedAdReady {
                            Button {
                                watchDailyBonusAd()
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "play.rectangle.fill")
                                    Text("WATCH AD FOR 50 COINS")
                                        .font(.system(size: 15, weight: .black, design: .rounded))
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.8)
                                    Spacer(minLength: 4)
                                    CoinAmount(amount: 50, size: 14)
                                }
                                .padding(.horizontal, 16)
                                .frame(height: 46)
                            }
                            .buttonStyle(ChunkyButtonStyle(colors: .glass, cornerRadius: 16, depth: 4))
                        }
                    }
                    .padding(.bottom, 10)
                }
                .padding(.horizontal, 22)
                .frame(maxWidth: 500)
            }
        }
        .fullScreenCover(isPresented: $showSettings) {
            SettingsView()
        }
        .fullScreenCover(isPresented: $showStats) {
            StatsView()
        }
        .fullScreenCover(isPresented: $showAchievements) {
            AchievementsView()
        }
        .fullScreenCover(isPresented: $showStore) {
            StoreView()
        }
        .sheet(isPresented: $showMissions) {
            DailyMissionsView()
        }
        .onAppear {
            // New day since the app was last opened? Fresh missions.
            missions.refreshIfNewDay()
            #if DEBUG
            if ScreenshotScenario.current == "missions" {
                showMissions = true
            }
            #endif
        }
    }

    /// Watch a rewarded ad for 50 bonus coins (once per day).
    /// Button is only visible when an ad is preloaded, so this should always succeed.
    private func watchDailyBonusAd() {
        guard let topVC = AdManager.shared.topViewController() else { return }

        AdManager.shared.showRewardedAd(from: topVC) { success in
            DispatchQueue.main.async {
                if success {
                    CoinManager.shared.earn(50, source: "daily_bonus_ad")
                    AnalyticsManager.shared.logCoinsEarned(amount: 50, source: "daily_bonus_ad")
                    lastDailyBonusDate = DailyChallengeDate.key()
                }
            }
        }
    }
}

// MARK: - Secondary Button

/// Smaller glass menu button (MISSIONS, HOW TO PLAY) with an optional badge like "1/3".
private struct SecondaryMenuButton: View {
    let icon: String
    let title: String
    let badge: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .bold))
                Text(title)
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                if let badge {
                    CandyBadge(text: badge)
                }
            }
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
        }
        .buttonStyle(ChunkyButtonStyle(colors: .glass, cornerRadius: 18, depth: 5))
    }
}
