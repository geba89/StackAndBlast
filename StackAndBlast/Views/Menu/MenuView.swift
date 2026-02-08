import SwiftUI

/// Main menu screen with game mode selection.
struct MenuView: View {
    @Binding var selectedMode: GameMode?

    var body: some View {
        ZStack {
            // Background
            Color(red: 0.118, green: 0.153, blue: 0.180) // #1E272E
                .ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                // Title
                VStack(spacing: 4) {
                    Text("STACK &")
                        .font(.system(size: 42, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                    Text("BLAST")
                        .font(.system(size: 52, weight: .black, design: .rounded))
                        .foregroundStyle(Color(red: 0.882, green: 0.439, blue: 0.333)) // Coral #E17055
                }

                Spacer()

                // Menu buttons
                VStack(spacing: 16) {
                    MenuButton(title: "PLAY", color: Color(red: 0.882, green: 0.439, blue: 0.333)) {
                        selectedMode = .classic
                    }

                    MenuButton(title: "DAILY CHALLENGE", color: Color(red: 0.035, green: 0.518, blue: 0.890)) {
                        selectedMode = .dailyChallenge
                    }

                    MenuButton(title: "BLAST RUSH", color: Color(red: 0.424, green: 0.361, blue: 0.906)) {
                        selectedMode = .blastRush
                    }
                }

                Spacer()

                // High score
                Text("BEST: 0")
                    .font(.system(.body, design: .rounded))
                    .fontWeight(.semibold)
                    .foregroundStyle(.gray)
                    .padding(.bottom, 32)
            }
            .padding(.horizontal, 32)
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
