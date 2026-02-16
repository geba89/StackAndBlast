import SwiftUI
import UIKit

/// Main menu screen with game mode selection, coin balance, and feature buttons.
struct MenuView: View {
    @Binding var selectedMode: GameMode?

    @State private var showSettings = false
    @State private var showStats = false
    @State private var showAchievements = false
    @State private var showStore = false
    @AppStorage("lastDailyChallengeDate") private var lastDailyChallengeDate = ""
    @AppStorage("lastDailyBonusDate") private var lastDailyBonusDate = ""

    /// Hold reference so SwiftUI's Observation framework can track property changes.
    private let networkMonitor = NetworkMonitor.shared

    /// Whether today's daily challenge has already been completed.
    private var isDailyChallengeCompleted: Bool {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return lastDailyChallengeDate == formatter.string(from: Date())
    }

    /// Whether the daily bonus ad has been watched today.
    private var hasDailyBonusToday: Bool {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return lastDailyBonusDate == formatter.string(from: Date())
    }

    var body: some View {
        ZStack {
            // Background
            Color(red: 0.118, green: 0.153, blue: 0.180) // #1E272E
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Top bar: coin balance + icons
                HStack {
                    // Coin balance
                    HStack(spacing: 6) {
                        Image(systemName: "bitcoinsign.circle.fill")
                            .font(.subheadline)
                            .foregroundStyle(.yellow)
                        Text("\(CoinManager.shared.balance)")
                            .font(.system(.subheadline, design: .rounded))
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                    }

                    Spacer()

                    // Trophy (achievements)
                    Button {
                        showAchievements = true
                    } label: {
                        Image(systemName: "trophy.fill")
                            .font(.title3)
                            .foregroundStyle(.white.opacity(0.7))
                            .padding(8)
                    }

                    // Cart (store)
                    Button {
                        showStore = true
                    } label: {
                        Image(systemName: "cart.fill")
                            .font(.title3)
                            .foregroundStyle(.white.opacity(0.7))
                            .padding(8)
                    }

                    // Stats
                    Button {
                        showStats = true
                    } label: {
                        Image(systemName: "chart.bar.fill")
                            .font(.title3)
                            .foregroundStyle(.white.opacity(0.7))
                            .padding(8)
                    }

                    // Settings
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .font(.title3)
                            .foregroundStyle(.white.opacity(0.7))
                            .padding(8)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)

                // Centered content — constrained on iPad
                VStack(spacing: 32) {
                    Spacer()

                    // Animated title
                    AnimatedTitleView()

                    // Streak display
                    if StreakManager.shared.currentStreak > 0 {
                        HStack(spacing: 6) {
                            Image(systemName: "flame.fill")
                                .foregroundStyle(.orange)
                            Text("\(StreakManager.shared.currentStreak) day streak")
                                .font(.system(.subheadline, design: .rounded))
                                .fontWeight(.bold)
                                .foregroundStyle(.orange)
                        }
                    }

                    Spacer()

                    // Offline banner — gameplay still works, only ads are unavailable
                    if !networkMonitor.isConnected {
                        HStack(spacing: 8) {
                            Image(systemName: "wifi.slash")
                                .font(.subheadline)
                            Text("Offline mode — ads unavailable")
                                .font(.system(.subheadline, design: .rounded))
                                .fontWeight(.medium)
                        }
                        .foregroundStyle(.white)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 20)
                        .background(Color.orange.opacity(0.7), in: RoundedRectangle(cornerRadius: 10))
                    }

                    // Menu buttons
                    VStack(spacing: 16) {
                        MenuButton(title: "PLAY", color: Color(red: 0.882, green: 0.439, blue: 0.333)) {
                            selectedMode = .classic
                        }

                        // Daily Challenge — show completion state
                        Button {
                            if !isDailyChallengeCompleted {
                                selectedMode = .dailyChallenge
                            }
                        } label: {
                            HStack {
                                Text(isDailyChallengeCompleted ? "DAILY COMPLETED" : "DAILY CHALLENGE")
                                    .font(.system(.headline, design: .rounded))
                                    .fontWeight(.bold)
                                    .foregroundStyle(.white)
                                if isDailyChallengeCompleted {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.white.opacity(0.7))
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                Color(red: 0.035, green: 0.518, blue: 0.890)
                                    .opacity(isDailyChallengeCompleted ? 0.5 : 1.0),
                                in: RoundedRectangle(cornerRadius: 12)
                            )
                        }
                        .disabled(isDailyChallengeCompleted)

                        MenuButton(title: "BLAST RUSH", color: Color(red: 0.424, green: 0.361, blue: 0.906)) {
                            selectedMode = .blastRush
                        }

                        // Daily bonus ad button (50 coins for watching, once per day)
                        if networkMonitor.isConnected && !hasDailyBonusToday {
                            Button {
                                watchDailyBonusAd()
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "play.rectangle.fill")
                                        .font(.subheadline)
                                    Text("WATCH AD FOR 50 COINS")
                                        .font(.system(.subheadline, design: .rounded))
                                        .fontWeight(.bold)
                                    Spacer()
                                    HStack(spacing: 3) {
                                        Image(systemName: "bitcoinsign.circle.fill")
                                            .font(.caption)
                                        Text("+50")
                                            .font(.system(.caption, design: .rounded))
                                            .fontWeight(.bold)
                                    }
                                    .foregroundStyle(.yellow)
                                }
                                .foregroundStyle(.white)
                                .padding(.vertical, 12)
                                .padding(.horizontal, 16)
                                .background(Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                            }
                        }
                    }

                    Spacer()
                }
                .padding(.horizontal, 32)
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
    }

    /// Watch a rewarded ad for 50 bonus coins (once per day).
    private func watchDailyBonusAd() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.windows.first?.rootViewController else { return }

        let presentAd = {
            AdManager.shared.showRewardedAd(from: rootVC) { success in
                if success {
                    CoinManager.shared.earn(50, source: "daily_bonus_ad")
                    AnalyticsManager.shared.logCoinsEarned(amount: 50, source: "daily_bonus_ad")
                    let formatter = DateFormatter()
                    formatter.dateFormat = "yyyy-MM-dd"
                    lastDailyBonusDate = formatter.string(from: Date())
                }
            }
        }

        if AdManager.shared.isRewardedAdReady {
            presentAd()
        } else {
            AdManager.shared.loadBombRewardedAd { ready in
                if ready { presentAd() }
            }
        }
    }
}

/// The available game modes.
enum GameMode {
    case classic
    case dailyChallenge
    case blastRush
}

// MARK: - Menu Button

/// Animated "STACK & BLAST" title with floating and glowing effects.
private struct AnimatedTitleView: View {
    @State private var isAnimating = false
    @State private var glowPhase: CGFloat = 0

    private let blastCoral = Color(red: 0.882, green: 0.439, blue: 0.333)
    private let blastOrange = Color(red: 1.0, green: 0.55, blue: 0.2)

    var body: some View {
        VStack(spacing: 4) {
            // "STACK &" — gentle floating/breathing
            Text("STACK &")
                .font(.system(size: 42, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .offset(y: isAnimating ? -3 : 3)
                .animation(
                    .easeInOut(duration: 2.0).repeatForever(autoreverses: true),
                    value: isAnimating
                )

            // "BLAST" — gradient sweep + pulsing glow + scale breathing
            Text("BLAST")
                .font(.system(size: 52, weight: .black, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [blastCoral, blastOrange, blastCoral],
                        startPoint: UnitPoint(x: glowPhase - 0.5, y: 0),
                        endPoint: UnitPoint(x: glowPhase + 0.5, y: 1)
                    )
                )
                .shadow(color: blastCoral.opacity(isAnimating ? 0.6 : 0.2), radius: isAnimating ? 12 : 4)
                .scaleEffect(isAnimating ? 1.02 : 0.98)
                .animation(
                    .easeInOut(duration: 1.5).repeatForever(autoreverses: true),
                    value: isAnimating
                )
        }
        .onAppear {
            isAnimating = true
            withAnimation(.linear(duration: 3.0).repeatForever(autoreverses: false)) {
                glowPhase = 1.5
            }
        }
    }
}

private struct MenuButton: View {
    let title: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(.headline, design: .rounded))
                .fontWeight(.bold)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(color, in: RoundedRectangle(cornerRadius: 12))
        }
    }
}
