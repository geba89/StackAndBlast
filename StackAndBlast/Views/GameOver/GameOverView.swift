import SwiftUI

/// Score summary screen shown when the game ends.
struct GameOverView: View {
    let score: Int
    let maxCombo: Int
    let totalBlasts: Int
    let piecesPlaced: Int
    let hasContinued: Bool
    let gameMode: GameMode
    let hasDoubledScore: Bool
    let coinsEarned: Int
    let dailyChallengeTier: DailyChallengeTier?
    let onUseBomb: () -> Void
    let onDoubleScore: () -> Void
    let onShare: () -> Void
    let onPlayAgain: () -> Void
    let onMainMenu: () -> Void

    var body: some View {
        ZStack {
            // Dimmed background
            Color.black.opacity(0.7)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Text("GAME OVER")
                    .font(.system(size: 36, weight: .black, design: .rounded))
                    .foregroundStyle(.white)

                // Score
                VStack(spacing: 4) {
                    Text("SCORE")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.gray)
                    Text("\(score)")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(red: 0.882, green: 0.439, blue: 0.333)) // Coral
                }

                // Coin earnings
                if coinsEarned > 0 {
                    HStack(spacing: 6) {
                        Image(systemName: "bitcoinsign.circle.fill")
                            .foregroundStyle(.yellow)
                        Text("+\(coinsEarned) coins")
                            .font(.system(.subheadline, design: .rounded))
                            .fontWeight(.bold)
                            .foregroundStyle(.yellow)
                    }
                }

                // Daily challenge tier badge
                if let tier = dailyChallengeTier {
                    DailyChallengeTierBadge(tier: tier)
                }

                // Stats grid
                HStack(spacing: 24) {
                    StatItem(label: "BLASTS", value: "\(totalBlasts)")
                    StatItem(label: "BEST COMBO", value: "\(maxCombo > 0 ? "×\(maxCombo)" : "-")")
                    StatItem(label: "PIECES", value: "\(piecesPlaced)")
                }

                // Action buttons
                VStack(spacing: 12) {
                    // USE BOMB — classic mode only, when ad is loaded and not yet used
                    if gameMode == .classic && !hasContinued && AdManager.shared.isRewardedAdReady {
                        Button(action: onUseBomb) {
                            HStack(spacing: 8) {
                                Image(systemName: "flame.fill")
                                    .font(.title3)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("USE BOMB")
                                        .font(.system(.headline, design: .rounded))
                                        .fontWeight(.bold)
                                    Text("Watch ad to clear 6×6 area")
                                        .font(.system(.caption2, design: .rounded))
                                        .opacity(0.8)
                                }
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                LinearGradient(
                                    colors: [
                                        Color(red: 1.0, green: 0.4, blue: 0.1),
                                        Color(red: 0.9, green: 0.2, blue: 0.1)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ),
                                in: RoundedRectangle(cornerRadius: 12)
                            )
                        }
                    }

                    // DOUBLE SCORE — classic mode only, when ad is loaded and not yet used
                    if gameMode == .classic && !hasDoubledScore && AdManager.shared.isDoubleScoreAdReady {
                        Button(action: onDoubleScore) {
                            HStack(spacing: 8) {
                                Image(systemName: "arrow.up.forward")
                                    .font(.title3)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("DOUBLE SCORE")
                                        .font(.system(.headline, design: .rounded))
                                        .fontWeight(.bold)
                                    Text("Watch ad to 2× your score")
                                        .font(.system(.caption2, design: .rounded))
                                        .opacity(0.8)
                                }
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.2, green: 0.7, blue: 0.3),
                                        Color(red: 0.1, green: 0.5, blue: 0.2)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ),
                                in: RoundedRectangle(cornerRadius: 12)
                            )
                        }
                    }

                    // SHARE button
                    Button(action: onShare) {
                        HStack(spacing: 8) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.subheadline)
                            Text("SHARE")
                                .font(.system(.subheadline, design: .rounded))
                                .fontWeight(.bold)
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.white.opacity(0.15), in: RoundedRectangle(cornerRadius: 12))
                    }

                    Button(action: onPlayAgain) {
                        Text("PLAY AGAIN")
                            .font(.system(.headline, design: .rounded))
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color(red: 0.882, green: 0.439, blue: 0.333), in: RoundedRectangle(cornerRadius: 12))
                    }

                    Button(action: onMainMenu) {
                        Text("MAIN MENU")
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundStyle(.gray)
                    }
                }
            }
            .padding(32)
            .frame(maxWidth: 420)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(red: 0.118, green: 0.153, blue: 0.180))
            )
            .padding(.horizontal, 24)
        }
    }
}

// MARK: - Daily Challenge Tier Badge

private struct DailyChallengeTierBadge: View {
    let tier: DailyChallengeTier

    private var tierColor: Color {
        switch tier {
        case .bronze: return Color(red: 0.804, green: 0.498, blue: 0.196)
        case .silver: return Color(white: 0.75)
        case .gold:   return Color.yellow
        }
    }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "medal.fill")
                .foregroundStyle(tierColor)
            Text("\(tier.label) — +\(tier.coinReward) coins")
                .font(.system(.subheadline, design: .rounded))
                .fontWeight(.bold)
                .foregroundStyle(tierColor)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(tierColor.opacity(0.15), in: Capsule())
    }
}

// MARK: - Stat Item

private struct StatItem: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(.title3, design: .rounded))
                .fontWeight(.bold)
                .foregroundStyle(.white)
            Text(label)
                .font(.system(.caption2, design: .rounded))
                .foregroundStyle(.gray)
        }
    }
}
