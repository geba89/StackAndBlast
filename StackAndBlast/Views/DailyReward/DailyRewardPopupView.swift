import SwiftUI

/// Sheet popup showing the 7-day reward schedule and a CLAIM button.
/// Presented on app launch when the daily reward hasn't been claimed yet.
struct DailyRewardPopupView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var claimedAmount: Int?
    @State private var showCoinAnimation = false

    private let streak = StreakManager.shared

    var body: some View {
        ZStack {
            Color(red: 0.118, green: 0.153, blue: 0.180)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                // Title
                VStack(spacing: 4) {
                    Text("DAILY REWARD")
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                    Text("Day \(streak.currentStreak + 1)")
                        .font(.system(.title3, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundStyle(Color(red: 0.882, green: 0.439, blue: 0.333))
                }

                // 7-day reward row
                HStack(spacing: 6) {
                    ForEach(0..<7, id: \.self) { index in
                        DayRewardCell(
                            day: index + 1,
                            coins: StreakManager.rewardSchedule[index],
                            isCompleted: index < streak.currentStreak % 7,
                            isCurrent: index == streak.currentStreak % 7,
                            isClaimed: claimedAmount != nil && index == (streak.currentStreak - 1) % 7
                        )
                    }
                }
                .padding(.horizontal, 4)

                // Current streak display
                if streak.currentStreak > 0 {
                    HStack(spacing: 6) {
                        Image(systemName: "flame.fill")
                            .foregroundStyle(.orange)
                        Text("\(streak.currentStreak) day streak!")
                            .font(.system(.subheadline, design: .rounded))
                            .fontWeight(.bold)
                            .foregroundStyle(.orange)
                    }
                }

                // Claim button or claimed state
                if let amount = claimedAmount {
                    VStack(spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: "bitcoinsign.circle.fill")
                                .foregroundStyle(.yellow)
                            Text("+\(amount) coins")
                                .font(.system(.title3, design: .rounded))
                                .fontWeight(.bold)
                                .foregroundStyle(.yellow)
                        }
                        .scaleEffect(showCoinAnimation ? 1.2 : 0.5)
                        .opacity(showCoinAnimation ? 1.0 : 0.0)
                        .animation(.spring(duration: 0.5, bounce: 0.4), value: showCoinAnimation)

                        Button {
                            dismiss()
                        } label: {
                            Text("CONTINUE")
                                .font(.system(.headline, design: .rounded))
                                .fontWeight(.bold)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color(red: 0.0, green: 0.722, blue: 0.580), in: RoundedRectangle(cornerRadius: 12))
                        }
                    }
                } else {
                    Button {
                        let reward = streak.claimDailyReward()
                        claimedAmount = reward
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            showCoinAnimation = true
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "gift.fill")
                            Text("CLAIM \(streak.todayReward) COINS")
                                .fontWeight(.bold)
                        }
                        .font(.system(.headline, design: .rounded))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(
                                colors: [.yellow, .orange],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            in: RoundedRectangle(cornerRadius: 12)
                        )
                    }
                }
            }
            .padding(24)
            .frame(maxWidth: 400)
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Day Reward Cell

private struct DayRewardCell: View {
    let day: Int
    let coins: Int
    let isCompleted: Bool
    let isCurrent: Bool
    let isClaimed: Bool

    var body: some View {
        VStack(spacing: 4) {
            Text("D\(day)")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(isCurrent ? .white : .gray)

            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(backgroundColor)
                    .frame(width: 44, height: 44)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(isCurrent ? Color.yellow : Color.clear, lineWidth: 2)
                    )

                if isCompleted || isClaimed {
                    Image(systemName: "checkmark")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                } else {
                    Image(systemName: "bitcoinsign.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(isCurrent ? .yellow : .gray)
                }
            }

            Text("\(coins)")
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(isCurrent ? .yellow : .gray)
        }
    }

    private var backgroundColor: Color {
        if isCompleted || isClaimed {
            return Color(red: 0.0, green: 0.722, blue: 0.580)
        } else if isCurrent {
            return Color.white.opacity(0.15)
        } else {
            return Color.white.opacity(0.05)
        }
    }
}
