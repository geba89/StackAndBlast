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
            // Candy Pop background, showing through the transparent game scene
            CandyBackground()

            // SpriteKit game scene
            SpriteView(scene: scene, options: [.allowsTransparency])
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
                VStack(spacing: 8) {
                    // Top row: pause · score (best score or combo above it) · coins
                    ZStack {
                        HStack {
                            CandyIconButton(systemName: "pause.fill", size: 44, label: "Pause") {
                                viewModel.togglePause()
                            }
                            Spacer()
                            HStack(spacing: 6) {
                                CoinIcon(size: 20)
                                Text("\(CoinManager.shared.balance)")
                                    .font(.system(size: 17, weight: .black, design: .rounded))
                                    .foregroundStyle(Color.candyGold)
                                    .contentTransition(.numericText())
                            }
                            .candyChip()
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel("\(CoinManager.shared.balance) coins")
                        }
                        ScoreDisplay(score: viewModel.engine.score,
                                     best: viewModel.bestScoreBeforeGame,
                                     combo: viewModel.currentCombo)
                    }
                    .frame(height: 64)

                    // Second row: goal (+ the clock in timed modes) · coin power-ups
                    HStack(spacing: 8) {
                        GoalChip(goal: viewModel.engine.currentMinGroupSize)
                        if viewModel.gameMode == .blastRush || viewModel.gameMode == .dailyChallenge {
                            TimerChip(timeRemaining: viewModel.timeRemaining)
                        }
                        Spacer(minLength: 4)

                        // Coin power-ups — usable during active play only, so they fade out
                        // when paused or at game over. They keep their space, so the board never moves.
                        HStack(spacing: 10) {
                            CoinPowerUpButton(
                                icon: "flame.fill",
                                name: "Bomb",
                                remaining: GameConstants.maxCoinBombsPerGame - viewModel.coinBombsUsed,
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

                            // Shuffle and Undo (hidden in Daily Challenge — its pieces are fixed)
                            if viewModel.gameMode != .dailyChallenge {
                                CoinPowerUpButton(
                                    icon: "shuffle",
                                    name: "Shuffle",
                                    remaining: GameConstants.maxShufflesPerGame - viewModel.shufflesUsed,
                                    price: GameConstants.coinShufflePrice,
                                    isEnabled: viewModel.canUseShuffle,
                                    isActive: false
                                ) {
                                    viewModel.useShuffle()
                                }

                                CoinPowerUpButton(
                                    icon: "arrow.uturn.backward",
                                    name: "Undo",
                                    remaining: GameConstants.maxUndosPerGame - viewModel.undosUsed,
                                    price: GameConstants.coinUndoPrice,
                                    isEnabled: viewModel.canUseUndo,
                                    isActive: false
                                ) {
                                    viewModel.useUndo()
                                }
                            }
                        }
                        .opacity(showsPowerUps ? 1 : 0)
                        .allowsHitTesting(showsPowerUps)
                        .accessibilityHidden(!showsPowerUps)
                        .animation(.easeInOut(duration: 0.2), value: showsPowerUps)
                    }
                    // Where the HUD ends → the scene lays the grid out just below it
                    .background(HUDBottomReporter { bottom in
                        // Not mid-blast: nothing in the HUD should move the board then
                        guard !viewModel.isAnimating else { return }
                        scene.setHUDBottom(bottom)
                    })

                    // Targeting hint — after the bomb ad nothing else tells the player what to do
                    if viewModel.isBombMode || viewModel.isCoinBombMode {
                        HintBanner(
                            icon: "flame.fill",
                            text: viewModel.isCoinBombMode
                                ? "Tap the grid to drop your bomb · tap 🔥 again to cancel"
                                : "Tap the grid to drop your bomb"
                        )
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.top, 6)
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

    /// Whether the coin power-up row is usable (active play, not paused).
    private var showsPowerUps: Bool {
        viewModel.engine.state == .playing && !viewModel.isPaused
    }
}

// MARK: - HUD Measurement

/// Reports where the view it's attached to ends, in points from the top of the window
/// (= the top of the full-screen game scene), whenever that changes.
private struct HUDBottomReporter: View {
    let onChange: (CGFloat) -> Void

    var body: some View {
        GeometryReader { proxy in
            let bottom = proxy.frame(in: .global).maxY
            Color.clear
                .onAppear { onChange(bottom) }
                .onChange(of: bottom) { _, newBottom in onChange(newBottom) }
        }
    }
}

// MARK: - HUD Pieces

/// The score in the middle of the HUD. Above it: the best score to beat, "NEW BEST!"
/// once it's beaten, or the combo while a cascade is going.
private struct ScoreDisplay: View {
    let score: Int
    let best: Int
    let combo: Int

    var body: some View {
        VStack(spacing: 0) {
            Group {
                if combo > 1 {
                    Text("COMBO ×\(combo)")
                        .foregroundStyle(combo >= 4 ? Color.candyGold
                                         : combo >= 3 ? Color(hex: 0xFF5A3C) : Color(hex: 0xFF9A3C))
                        .transition(.scale.combined(with: .opacity))
                } else if best > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "crown.fill")
                        Text(score > best ? "NEW BEST!" : best.grouped)
                    }
                    .foregroundStyle(Color(hex: 0xFFD76A))
                }
            }
            .font(.system(size: 14, weight: .heavy, design: .rounded))
            .frame(height: 17)

            Text(score.grouped)
                .font(.system(size: 44, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .shadow(color: Color(hex: 0x140A46, opacity: 0.55), radius: 0, y: 4)
                .contentTransition(.numericText())
                .animation(.spring(duration: 0.3), value: score)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: 190)
        .animation(.spring(duration: 0.3, bounce: 0.4), value: combo)
        .accessibilityElement(children: .combine)
    }
}

/// "◎ GOAL 12" — how many connected blocks a blast needs right now.
private struct GoalChip: View {
    let goal: Int

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "target")
                .font(.system(size: 14, weight: .bold))
            Text("GOAL")
                .font(.system(size: 12, weight: .heavy, design: .rounded))
                .tracking(0.6)
            Text("\(goal)")
                .font(.system(size: 19, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .contentTransition(.numericText())
                .animation(.spring(duration: 0.3), value: goal)
        }
        .foregroundStyle(Color(hex: 0xFFB86B))
        .candyChip()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Goal: \(goal) connected blocks")
    }
}

/// Countdown for Blast Rush and the Daily Challenge. Turns red and blinks under 10 seconds.
private struct TimerChip: View {
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
        HStack(spacing: 5) {
            Image(systemName: "timer")
                .font(.system(size: 14, weight: .bold))
            Text(formattedTime)
                .font(.system(size: 17, weight: .black, design: .rounded))
                .monospacedDigit()
        }
        .foregroundStyle(isUrgent ? Color(hex: 0xFF6B6B) : .white)
        .opacity(isUrgent ? (Int(timeRemaining * 5) % 2 == 0 ? 1.0 : 0.6) : 1.0)
        .animation(.easeInOut(duration: 0.1), value: timeRemaining)
        .candyChip()
    }
}

/// A coin power-up: a chunky purple button with a count badge, its price below.
private struct CoinPowerUpButton: View {
    let icon: String
    let name: String
    let remaining: Int
    let price: Int
    let isEnabled: Bool
    /// Bomb targeting in progress (tap again to cancel).
    let isActive: Bool
    let action: () -> Void

    private var isUsable: Bool { isEnabled || isActive }

    var body: some View {
        VStack(spacing: 1) {
            Button(action: action) {
                Image(systemName: icon)
                    .font(.system(size: 19, weight: .bold))
                    .frame(width: 44, height: 40)
            }
            .buttonStyle(ChunkyButtonStyle(colors: isActive ? .orange : .purple, cornerRadius: 14, depth: 4))
            .disabled(!isUsable)
            .overlay(alignment: .topTrailing) {
                Text("\(remaining)")
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(minWidth: 18, minHeight: 18)
                    .background(Circle().fill(Color(hex: 0xFF4D6D)))
                    .offset(x: 6, y: -6)
                    .opacity(isUsable ? 1 : 0.6)
            }
            CoinAmount(amount: price, size: 11)
                .opacity(isUsable ? 1 : 0.55)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(name), \(remaining) left, \(price) coins")
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
            Color.black.opacity(0.55)
                .ignoresSafeArea()

            VStack(spacing: 22) {
                Text("PAUSED")
                    .font(.system(size: 40, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .shadow(color: Color(hex: 0x2A1B7A), radius: 0, y: 4)

                VStack(spacing: 12) {
                    PauseButton(title: "RESUME", icon: "play.fill", colors: .green, action: onResume)
                    if let onRestart {
                        PauseButton(title: "RESTART", icon: "arrow.counterclockwise", colors: .blue, action: onRestart)
                    }
                    PauseButton(title: "SETTINGS", icon: "gearshape.fill", colors: .glass, action: onSettings)
                    PauseButton(title: "QUIT", icon: "house.fill", colors: .orange, action: onQuit)
                }
            }
            .padding(28)
            .frame(maxWidth: 360)
            .background(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(LinearGradient(colors: [.candyTop, .candyBottom], startPoint: .top, endPoint: .bottom))
            )
            .overlay(RoundedRectangle(cornerRadius: 30, style: .continuous).strokeBorder(.white.opacity(0.14), lineWidth: 1.5))
            .shadow(color: .black.opacity(0.4), radius: 24, y: 12)
            .padding(.horizontal, 32)
        }
    }
}

private struct PauseButton: View {
    let title: String
    let icon: String
    let colors: CandyButtonColors
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.system(size: 19, weight: .black, design: .rounded))
                .frame(maxWidth: .infinity)
                .frame(height: 52)
        }
        .buttonStyle(ChunkyButtonStyle(colors: colors, cornerRadius: 18, depth: 5))
    }
}

// MARK: - Tutorial Card

/// The tutorial's instruction card: step, title, what to do (or what just
/// happened), and the NEXT / LET'S PLAY! button once the move has played out.
private struct TutorialCardView: View {
    let card: GameViewModel.TutorialCard
    let onButton: () -> Void
    let onSkip: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(card.step)
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundStyle(Color.candyGold)
                Text(card.title)
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                Spacer()
                if card.canSkip {
                    Button("Skip", action: onSkip)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.6))
                }
            }

            Text(card.message)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.92))
                .fixedSize(horizontal: false, vertical: true)
                // Animate the switch from instruction → result
                .id(card.message)
                .transition(.opacity)

            if let buttonTitle = card.buttonTitle {
                HStack {
                    Spacer()
                    Button(action: onButton) {
                        Text(buttonTitle)
                            .font(.system(size: 16, weight: .black, design: .rounded))
                            .padding(.horizontal, 22)
                            .frame(height: 40)
                    }
                    .buttonStyle(ChunkyButtonStyle(colors: .green, cornerRadius: 14, depth: 4))
                }
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Color.candyInk.opacity(0.8)))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(Color.candyGold.opacity(0.55), lineWidth: 1.5))
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
                .foregroundStyle(Color(hex: 0xFF9A3C))
            Text(text)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Capsule().fill(Color.candyInk.opacity(0.88)))
        .overlay(Capsule().strokeBorder(Color(hex: 0xFF9A3C).opacity(0.7), lineWidth: 1.5))
        .padding(.horizontal)
        .allowsHitTesting(false)
    }
}
