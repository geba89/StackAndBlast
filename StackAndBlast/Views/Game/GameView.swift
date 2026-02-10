import SwiftUI
import SpriteKit

/// SwiftUI wrapper that hosts the SpriteKit GameScene.
struct GameView: View {
    @Bindable var viewModel: GameViewModel

    /// Persistent SpriteKit scene instance — must NOT be a computed property
    /// or it gets recreated on every SwiftUI re-render, losing all state.
    @State private var scene: GameScene = {
        let scene = GameScene()
        scene.size = CGSize(width: 390, height: 844)
        scene.scaleMode = .aspectFill
        return scene
    }()

    var body: some View {
        ZStack {
            // SpriteKit game scene
            SpriteView(scene: scene)
                .ignoresSafeArea()

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

                    Spacer()

                    // Combo counter — visible during blast cascades
                    if viewModel.currentCombo > 1 {
                        ComboLabel(level: viewModel.currentCombo)
                            .transition(.scale.combined(with: .opacity))
                            .animation(.spring(duration: 0.3, bounce: 0.4), value: viewModel.currentCombo)
                    }

                    // Blast Rush timer
                    if viewModel.gameMode == .blastRush {
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

                Spacer()
            }

            // Pause overlay
            if viewModel.isPaused {
                PauseOverlay(
                    onResume: { viewModel.togglePause() },
                    onRestart: { viewModel.startGame() },
                    onQuit: { viewModel.quitToMenu() }
                )
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.isPaused)
        .onAppear {
            scene.viewModel = viewModel
            viewModel.scene = scene
            // Push current engine state — startGame may have run before scene was wired
            scene.updateGrid(viewModel.engine.grid)
            scene.updateTray(viewModel.engine.tray)
        }
    }
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
    let onRestart: () -> Void
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
                    PauseButton(title: "RESTART", color: Color(red: 0.035, green: 0.518, blue: 0.890)) {
                        onRestart()
                    }
                    PauseButton(title: "QUIT", color: Color(red: 0.424, green: 0.361, blue: 0.906)) {
                        onQuit()
                    }
                }
            }
            .padding(32)
        }
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
                .frame(width: 200)
                .padding(.vertical, 14)
                .background(color, in: RoundedRectangle(cornerRadius: 12))
        }
    }
}
