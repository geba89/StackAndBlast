import SwiftUI
import SpriteKit

/// SwiftUI wrapper that hosts the SpriteKit GameScene.
struct GameView: View {
    @Bindable var viewModel: GameViewModel

    /// Whether the app is in the foreground (used to auto-pause).
    @Environment(\.scenePhase) private var scenePhase

    /// Persistent SpriteKit scene instance — must NOT be a computed property
    /// or it gets recreated on every SwiftUI re-render, losing all state.
    /// Uses `.resizeFill` so the scene automatically adapts to the actual view size
    /// on any device, preventing content from being cropped or going out of bounds.
    @State private var scene: GameScene = {
        let scene = GameScene()
        scene.size = CGSize(width: 390, height: 844) // initial size; resizeFill overrides
        scene.scaleMode = .resizeFill
        return scene
    }()

    var body: some View {
        ZStack {
            // SpriteKit game scene
            SpriteView(scene: scene)
                .ignoresSafeArea()

            if let card = viewModel.tutorialCard {
                // Tutorial: an instruction card replaces the HUD
                VStack {
                    TutorialCardView(
                        card: card,
                        onButton: { viewModel.tutorialButtonTapped() },
                        onSkip: { viewModel.finishTutorial() }
                    )
                    Spacer()
                }
                .transition(.opacity)
            } else {
                // HUD overlay
                VStack {
                    // Top bar: Score + Combo + Timer + Pause
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("SCORE")
                                .font(.system(.caption2, design: .rounded))
                                .fontWeight(.medium)
                                .foregroundStyle(.gray)
                            Text("\(viewModel.engine.score)")
                                .font(.system(.title2, design: .rounded))
                                .fontWeight(.bold)
                                .foregroundStyle(.white)
                                .contentTransition(.numericText())
                                .animation(.spring(duration: 0.3), value: viewModel.engine.score)
                        }

                        // Current blast threshold indicator
                        VStack(spacing: 2) {
                            Text("GOAL")
                                .font(.system(.caption2, design: .rounded))
                                .fontWeight(.medium)
                                .foregroundStyle(.gray)
                            Text("\(viewModel.engine.currentMinGroupSize)")
                                .font(.system(.title3, design: .rounded))
                                .fontWeight(.bold)
                                .foregroundStyle(Color(red: 1.0, green: 0.6, blue: 0.2))
                                .contentTransition(.numericText())
                                .animation(.spring(duration: 0.3), value: viewModel.engine.currentMinGroupSize)
                        }

                        // Coin balance
                        HStack(spacing: 3) {
                            Image(systemName: "bitcoinsign.circle.fill")
                                .font(.caption)
                                .foregroundStyle(.yellow)
                            Text("\(CoinManager.shared.balance)")
                                .font(.system(.caption, design: .rounded))
                                .fontWeight(.bold)
                                .foregroundStyle(.yellow)
                        }

                        Spacer()

                        // Combo counter — visible during blast cascades
                        if viewModel.currentCombo > 1 {
                            ComboLabel(level: viewModel.currentCombo)
                                .transition(.scale.combined(with: .opacity))
                                .animation(.spring(duration: 0.3, bounce: 0.4), value: viewModel.currentCombo)
                        }

                        // Countdown timer (Blast Rush and Daily Challenge)
                        if viewModel.gameMode == .blastRush || viewModel.gameMode == .dailyChallenge {
                            Spacer()
                            BlastRushTimerLabel(timeRemaining: viewModel.timeRemaining)
                        }

                        Spacer()

                        Button {
                            viewModel.togglePause()
                        } label: {
                            Image(systemName: "pause.fill")
                                .font(.title3)
                                .foregroundStyle(.white)
                                .padding(8)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)

                    // Coin power-up buttons (visible during active play, hidden when paused/game over)
                    if viewModel.engine.state == .playing && !viewModel.isPaused {
                        HStack(spacing: 10) {
                            Spacer()

                            // Coin Bomb
                            CoinPowerUpButton(
                                icon: "flame.fill",
                                remaining: GameConstants.maxCoinBombsPerGame - viewModel.coinBombsUsed,
                                maxUses: GameConstants.maxCoinBombsPerGame,
                                price: GameConstants.coinBombPrice,
                                isEnabled: viewModel.canUseCoinBomb,
                                isActive: viewModel.isCoinBombMode
                            ) {
                                // Tapping again while targeting backs out (coins are only spent on detonation)
                                if viewModel.isCoinBombMode {
                                    viewModel.cancelCoinBomb()
                                } else {
                                    viewModel.activateCoinBomb()
                                }
                            }

                            // Shuffle (hidden in Daily Challenge)
                            if viewModel.gameMode != .dailyChallenge {
                                CoinPowerUpButton(
                                    icon: "shuffle",
                                    remaining: GameConstants.maxShufflesPerGame - viewModel.shufflesUsed,
                                    maxUses: GameConstants.maxShufflesPerGame,
                                    price: GameConstants.coinShufflePrice,
                                    isEnabled: viewModel.canUseShuffle,
                                    isActive: false
                                ) {
                                    viewModel.useShuffle()
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 4)
                        .transition(.opacity)
                    }

                    // Targeting hint — after the bomb ad nothing else tells the player what to do
                    if viewModel.isBombMode || viewModel.isCoinBombMode {
                        HintBanner(
                            icon: "flame.fill",
                            text: viewModel.isCoinBombMode
                                ? "Tap the grid to drop your bomb · tap 🔥 again to cancel"
                                : "Tap the grid to drop your bomb"
                        )
                        .padding(.top, 8)
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    Spacer()
                }
                .animation(.easeInOut(duration: 0.2), value: viewModel.isBombMode || viewModel.isCoinBombMode)
            }

            // Pause overlay
            if viewModel.isPaused {
                PauseOverlay(
                    onResume: { viewModel.togglePause() },
                    onSettings: { showSettings = true },
                    // The Daily Challenge is one attempt per day, so no restart there
                    onRestart: viewModel.canRestart ? { viewModel.restart() } : nil,
                    onQuit: { viewModel.quitToMenu() }
                )
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.isPaused)
        // Auto-pause when the app leaves the foreground (call, app switcher, Control Center)
        .onChange(of: scenePhase) { _, phase in
            if phase != .active {
                viewModel.pauseIfPlaying()
            }
        }
        .fullScreenCover(isPresented: $showSettings) {
            SettingsView(onColorblindChanged: {
                scene.refreshAllBlocks()
            })
        }
        // Refresh grid + blocks when the active skin changes (e.g. from SkinPickerView)
        .onChange(of: SettingsManager.shared.activeSkinID) {
            scene.refreshAllBlocks()
        }
        .onAppear {
            scene.viewModel = viewModel
            viewModel.scene = scene
            // Push current state — startGame may have run before the scene was wired
            viewModel.syncScene()
        }
    }

    @State private var showSettings = false
}

// MARK: - Combo Label

/// Displays the cascade combo multiplier with escalating visual effects per GDD.
private struct ComboLabel: View {
    let level: Int

    private var color: Color {
        switch level {
        case 2: return .orange
        case 3: return .red
        default: return Color(red: 1.0, green: 0.84, blue: 0.0) // Gold
        }
    }

    var body: some View {
        Text("×\(level)")
            .font(.system(size: level >= 4 ? 32 : 28, weight: .black, design: .rounded))
            .foregroundStyle(color)
            .shadow(color: color.opacity(level >= 3 ? 0.8 : 0), radius: 8)
    }
}

// MARK: - Blast Rush Timer Label

/// Displays the countdown timer for Blast Rush mode.
/// Turns red and pulses when under 10 seconds remaining.
private struct BlastRushTimerLabel: View {
    let timeRemaining: TimeInterval

    private var isUrgent: Bool { timeRemaining < 10 }

    private var formattedTime: String {
        let clamped = max(timeRemaining, 0)
        let minutes = Int(clamped) / 60
        let seconds = Int(clamped) % 60
        let tenths = Int(clamped * 10) % 10
        return String(format: "%d:%02d.%d", minutes, seconds, tenths)
    }

    var body: some View {
        Text(formattedTime)
            .font(.system(.title3, design: .monospaced))
            .fontWeight(.bold)
            .foregroundStyle(isUrgent ? .red : .white)
            .opacity(isUrgent ? (Int(timeRemaining * 5) % 2 == 0 ? 1.0 : 0.6) : 1.0)
            .animation(.easeInOut(duration: 0.1), value: timeRemaining)
    }
}

// MARK: - Pause Overlay

private struct PauseOverlay: View {
    let onResume: () -> Void
    let onSettings: () -> Void
    /// `nil` hides the RESTART button (Daily Challenge).
    let onRestart: (() -> Void)?
    let onQuit: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Text("PAUSED")
                    .font(.system(size: 36, weight: .black, design: .rounded))
                    .foregroundStyle(.white)

                VStack(spacing: 12) {
                    PauseButton(title: "RESUME", color: Color(red: 0.0, green: 0.722, blue: 0.580)) {
                        onResume()
                    }
                    PauseButton(title: "SETTINGS", color: Color(red: 0.4, green: 0.4, blue: 0.45)) {
                        onSettings()
                    }
                    if let onRestart {
                        PauseButton(title: "RESTART", color: Color(red: 0.035, green: 0.518, blue: 0.890)) {
                            onRestart()
                        }
                    }
                    PauseButton(title: "QUIT", color: Color(red: 0.424, green: 0.361, blue: 0.906)) {
                        onQuit()
                    }
                }
            }
            .frame(maxWidth: 400)
            .padding(32)
        }
    }
}

/// The tutorial's instruction card: step, title, what to do (or what just
/// happened), and the NEXT / LET'S PLAY! button once the move has played out.
private struct TutorialCardView: View {
    let card: GameViewModel.TutorialCard
    let onButton: () -> Void
    let onSkip: () -> Void

    private let coral = Color(red: 0.882, green: 0.439, blue: 0.333)

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(card.step)
                    .font(.system(.caption, design: .rounded))
                    .fontWeight(.bold)
                    .foregroundStyle(coral)
                Text(card.title)
                    .font(.system(.headline, design: .rounded))
                    .fontWeight(.black)
                    .foregroundStyle(.white)
                Spacer()
                if card.canSkip {
                    Button("Skip", action: onSkip)
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(.gray)
                }
            }

            Text(card.message)
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(.white.opacity(0.9))
                .fixedSize(horizontal: false, vertical: true)
                // Animate the switch from instruction → result
                .id(card.message)
                .transition(.opacity)

            if let buttonTitle = card.buttonTitle {
                HStack {
                    Spacer()
                    Button(action: onButton) {
                        Text(buttonTitle)
                            .font(.system(.subheadline, design: .rounded))
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 8)
                            .background(coral, in: Capsule())
                    }
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(red: 0.118, green: 0.153, blue: 0.180).opacity(0.95))
        )
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(coral.opacity(0.6), lineWidth: 1))
        .frame(maxWidth: 500)
        .padding(.horizontal)
        .padding(.top, 8)
        .animation(.easeInOut(duration: 0.25), value: card.message)
    }
}

/// Small floating instruction pill (e.g. "Tap the grid to drop your bomb").
/// Touches pass straight through it to the board underneath.
private struct HintBanner: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(.orange)
            Text(text)
                .font(.system(.subheadline, design: .rounded))
                .fontWeight(.semibold)
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.black.opacity(0.75), in: Capsule())
        .overlay(Capsule().strokeBorder(Color.orange.opacity(0.6), lineWidth: 1))
        .padding(.horizontal)
        .allowsHitTesting(false)
    }
}

/// Compact button for coin-purchasable power-ups shown during gameplay.
private struct CoinPowerUpButton: View {
    let icon: String
    let remaining: Int
    let maxUses: Int
    let price: Int
    let isEnabled: Bool
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                Text("\(remaining)/\(maxUses)")
                    .font(.system(.caption2, design: .rounded))
                    .fontWeight(.bold)
                HStack(spacing: 2) {
                    Image(systemName: "bitcoinsign.circle.fill")
                        .font(.system(size: 9))
                    Text("\(price)")
                        .font(.system(.caption2, design: .rounded))
                        .fontWeight(.bold)
                }
                .foregroundStyle(.yellow)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(isActive ? Color.orange.opacity(0.6) : Color.white.opacity(isEnabled ? 0.15 : 0.05))
                    .overlay(
                        Capsule()
                            .strokeBorder(isActive ? Color.orange : Color.clear, lineWidth: 1.5)
                    )
            )
            .opacity(isEnabled || isActive ? 1.0 : 0.4)
        }
        .disabled(!isEnabled && !isActive)
    }
}

private struct PauseButton: View {
    let title: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(.headline, design: .rounded))
                .fontWeight(.bold)
                .foregroundStyle(.white)
                .frame(maxWidth: 280)
                .padding(.vertical, 14)
                .background(color, in: RoundedRectangle(cornerRadius: 12))
        }
    }
}
