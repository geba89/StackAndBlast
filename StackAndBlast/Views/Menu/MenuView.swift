import SwiftUI

/// Main menu screen with game mode selection.
struct MenuView: View {
    @Binding var selectedMode: GameMode?

    @State private var showSettings = false
    @State private var showStats = false
    @AppStorage("lastDailyChallengeDate") private var lastDailyChallengeDate = ""

    /// Hold reference so SwiftUI's Observation framework can track property changes.
    private let networkMonitor = NetworkMonitor.shared

    /// Whether today's daily challenge has already been completed.
    private var isDailyChallengeCompleted: Bool {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return lastDailyChallengeDate == formatter.string(from: Date())
    }

    var body: some View {
        ZStack {
            // Background
            Color(red: 0.118, green: 0.153, blue: 0.180) // #1E272E
                .ignoresSafeArea()

            VStack(spacing: 32) {
                // Top bar: gear + stats icons
                HStack {
                    Spacer()
                    Button {
                        showStats = true
                    } label: {
                        Image(systemName: "chart.bar.fill")
                            .font(.title3)
                            .foregroundStyle(.white.opacity(0.7))
                            .padding(8)
                    }
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

                // No-connection banner
                if !networkMonitor.isConnected {
                    HStack(spacing: 8) {
                        Image(systemName: "wifi.slash")
                            .font(.subheadline)
                        Text("Internet connection required")
                            .font(.system(.subheadline, design: .rounded))
                            .fontWeight(.medium)
                    }
                    .foregroundStyle(.white)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 20)
                    .background(Color.red.opacity(0.7), in: RoundedRectangle(cornerRadius: 10))
                }

                // Menu buttons
                VStack(spacing: 16) {
                    MenuButton(title: "PLAY", color: Color(red: 0.882, green: 0.439, blue: 0.333)) {
                        selectedMode = .classic
                    }
                    .disabled(!networkMonitor.isConnected)
                    .opacity(networkMonitor.isConnected ? 1.0 : 0.4)

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
                                .opacity(isDailyChallengeCompleted || !networkMonitor.isConnected ? 0.5 : 1.0),
                            in: RoundedRectangle(cornerRadius: 12)
                        )
                    }
                    .disabled(isDailyChallengeCompleted || !networkMonitor.isConnected)

                    MenuButton(title: "BLAST RUSH", color: Color(red: 0.424, green: 0.361, blue: 0.906)) {
                        selectedMode = .blastRush
                    }
                    .disabled(!networkMonitor.isConnected)
                    .opacity(networkMonitor.isConnected ? 1.0 : 0.4)
                }

                Spacer()
            }
            .padding(.horizontal, 32)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showStats) {
            StatsView()
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

