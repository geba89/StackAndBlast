import SwiftUI

/// Score summary screen shown when the game ends.
struct GameOverView: View {
    let score: Int
    /// Best score for this mode (including this game).
    let bestScore: Int
    /// Whether this game set a new personal best.
    let isNewBest: Bool
    let maxCombo: Int
    let totalBlasts: Int
    let piecesPlaced: Int
    let hasContinued: Bool
    let gameMode: GameMode
    let hasDoubledScore: Bool
    let coinsEarned: Int
    let dailyChallengeTier: DailyChallengeTier?
    /// "PLAY AGAIN", or "PLAY CLASSIC" after the (once-a-day) Daily Challenge.
    let playAgainTitle: String
    /// Whether the last move can be taken back for coins (Classic only).
    let canUndo: Bool
    let onUseBomb: () -> Void
    let onDoubleScore: () -> Void
    let onUndo: () -> Void
    let onShare: () -> Void
    let onPlayAgain: () -> Void
    let onMainMenu: () -> Void

    var body: some View {
        ZStack {
            // Dimmed background
            Color.black.opacity(0.6)
                .ignoresSafeArea()

            // The card, scrollable only if a small screen can't fit every button
            ViewThatFits(in: .vertical) {
                card
                ScrollView(showsIndicators: false) {
                    card.padding(.vertical, 12)
                }
            }
        }
    }

    private var card: some View {
        VStack(spacing: 16) {
            OutlinedTitle(text: "GAME OVER", size: 38,
                          fill: [.white, Color(hex: 0xE4DEFF)],
                          outline: Color(hex: 0x2A1B7A), drop: Color(hex: 0x1A1060))

            // Score
            VStack(spacing: 4) {
                Text("SCORE")
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .tracking(1.2)
                    .foregroundStyle(.white.opacity(0.6))
                OutlinedTitle(text: score.grouped, size: 54)

                // Personal best: celebrate a new one, otherwise show the target to beat
                if isNewBest {
                    NewBestRibbon()
                        .padding(.top, 6)
                } else if bestScore > 0 {
                    HStack(spacing: 5) {
                        Image(systemName: "crown.fill")
                        Text("BEST \(bestScore.grouped)")
                    }
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color(hex: 0xFFD76A))
                    .candyChip(height: 30)
                    .padding(.top, 6)
                }
            }

            // Coin earnings + daily challenge medal
            if coinsEarned > 0 || dailyChallengeTier != nil {
                HStack(spacing: 8) {
                    if coinsEarned > 0 {
                        HStack(spacing: 6) {
                            CoinIcon(size: 20)
                            Text("+\(coinsEarned)")
                                .font(.system(size: 17, weight: .black, design: .rounded))
                                .foregroundStyle(Color.candyGold)
                        }
                        .candyChip()
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("\(coinsEarned) coins earned")
                    }
                    if let tier = dailyChallengeTier {
                        DailyChallengeTierBadge(tier: tier)
                    }
                }
            }

            // Stats
            HStack(spacing: 10) {
                StatTile(label: "BLASTS", value: "\(totalBlasts)")
                StatTile(label: "BEST COMBO", value: maxCombo > 0 ? "×\(maxCombo)" : "-")
                StatTile(label: "PIECES", value: "\(piecesPlaced)")
            }

            // Action buttons
            VStack(spacing: 10) {
                // USE BOMB — classic mode only, when ad is loaded and not yet used.
                // Hidden once the score is doubled: a doubled score is final, and
                // continuing would carry the doubled score into more play.
                if gameMode == .classic && !hasContinued && !hasDoubledScore && AdManager.shared.isRewardedAdReady {
                    Button(action: onUseBomb) {
                        AdOfferLabel(icon: "flame.fill", title: "USE BOMB", subtitle: "Watch an ad to clear a 6×6 area")
                    }
                    .buttonStyle(ChunkyButtonStyle(colors: .orange, cornerRadius: 18, depth: 5))
                }

                // DOUBLE SCORE — classic mode only, when ad is loaded and not yet used
                if gameMode == .classic && !hasDoubledScore && AdManager.shared.isDoubleScoreAdReady {
                    Button(action: onDoubleScore) {
                        AdOfferLabel(icon: "arrow.up.forward", title: "DOUBLE SCORE", subtitle: "Watch an ad to 2× your score")
                    }
                    .buttonStyle(ChunkyButtonStyle(colors: .blue, cornerRadius: 18, depth: 5))
                }

                // UNDO — take back the move that ended the game, for coins
                if canUndo {
                    Button(action: onUndo) {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.uturn.backward")
                                .font(.system(size: 16, weight: .bold))
                            Text("UNDO LAST MOVE")
                                .font(.system(size: 16, weight: .black, design: .rounded))
                            CoinAmount(amount: GameConstants.coinUndoPrice, size: 14)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                    }
                    .buttonStyle(ChunkyButtonStyle(colors: .purple, cornerRadius: 16, depth: 5))
                }

                Button(action: onPlayAgain) {
                    Label(playAgainTitle, systemImage: "play.fill")
                        .font(.system(size: 21, weight: .black, design: .rounded))
                        .frame(maxWidth: .infinity)
                        .frame(height: 58)
                }
                .buttonStyle(ChunkyButtonStyle(colors: .green, cornerRadius: 20, depth: 6))

                HStack(spacing: 10) {
                    Button(action: onShare) {
                        Label("SHARE", systemImage: "square.and.arrow.up")
                            .font(.system(size: 15, weight: .black, design: .rounded))
                            .frame(maxWidth: .infinity)
                            .frame(height: 46)
                    }
                    .buttonStyle(ChunkyButtonStyle(colors: .glass, cornerRadius: 16, depth: 4))

                    Button(action: onMainMenu) {
                        Label("MENU", systemImage: "house.fill")
                            .font(.system(size: 15, weight: .black, design: .rounded))
                            .frame(maxWidth: .infinity)
                            .frame(height: 46)
                    }
                    .buttonStyle(ChunkyButtonStyle(colors: .glass, cornerRadius: 16, depth: 4))
                }
            }
        }
        .padding(24)
        .frame(maxWidth: 400)
        .background(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(LinearGradient(colors: [.candyTop, .candyMid, .candyBottom], startPoint: .top, endPoint: .bottom))
        )
        .overlay(RoundedRectangle(cornerRadius: 32, style: .continuous).strokeBorder(.white.opacity(0.14), lineWidth: 1.5))
        .shadow(color: .black.opacity(0.45), radius: 28, y: 14)
        .padding(.horizontal, 20)
    }
}

// MARK: - New Best Ribbon

/// Gold "🏆 NEW BEST!" ribbon that gently pulses.
private struct NewBestRibbon: View {
    @State private var isPulsing = false

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "trophy.fill")
            Text("NEW BEST!")
        }
        .font(.system(size: 17, weight: .black, design: .rounded))
        .foregroundStyle(Color.candyCocoa)
        .padding(.horizontal, 16)
        .frame(height: 36)
        .background(
            Capsule().fill(LinearGradient(colors: [Color(hex: 0xFFF1A6), Color(hex: 0xFFC53D)],
                                          startPoint: .top, endPoint: .bottom))
        )
        .background(Capsule().fill(Color(hex: 0xB86E00)).offset(y: 3))
        .scaleEffect(isPulsing ? 1.06 : 1.0)
        .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: isPulsing)
        .onAppear { isPulsing = true }
    }
}

// MARK: - Ad Offer Label

/// Label for a rewarded-ad offer: icon, title and a line about what the ad gives.
private struct AdOfferLabel: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .bold))
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 17, weight: .black, design: .rounded))
                Text(subtitle)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .opacity(0.85)
            }
            Spacer(minLength: 4)
            Image(systemName: "play.rectangle.fill")
                .font(.system(size: 18))
                .opacity(0.85)
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity)
        .frame(height: 56)
    }
}

// MARK: - Daily Challenge Tier Badge

private struct DailyChallengeTierBadge: View {
    let tier: DailyChallengeTier

    private var tierColor: Color {
        switch tier {
        case .bronze: return Color(red: 0.93, green: 0.62, blue: 0.35)
        case .silver: return Color(white: 0.85)
        case .gold:   return Color.candyGold
        }
    }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "medal.fill")
            Text("\(tier.label) · +\(tier.coinReward)")
        }
        .font(.system(size: 15, weight: .black, design: .rounded))
        .foregroundStyle(tierColor)
        .candyChip()
    }
}

// MARK: - Stat Tile

private struct StatTile: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundStyle(.white)
            Text(label)
                .font(.system(size: 10, weight: .heavy, design: .rounded))
                .tracking(0.6)
                .foregroundStyle(.white.opacity(0.6))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.candyInk.opacity(0.45)))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(.white.opacity(0.1), lineWidth: 1))
        .accessibilityElement(children: .combine)
    }
}
