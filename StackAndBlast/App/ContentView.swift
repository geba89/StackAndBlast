import SwiftUI

/// Root view that handles navigation between menu and game screens.
struct ContentView: View {
    @State private var selectedMode: GameMode?
    @State private var viewModel = GameViewModel()

    var body: some View {
        ZStack {
            if selectedMode != nil {
                // Active game
                GameView(viewModel: viewModel)
                    .transition(.opacity)

                // Game over overlay
                if viewModel.engine.state == .gameOver {
                    GameOverView(
                        score: viewModel.engine.score,
                        maxCombo: viewModel.engine.maxCombo,
                        totalBlasts: viewModel.engine.totalBlasts,
                        piecesPlaced: viewModel.engine.piecesPlaced,
                        onPlayAgain: {
                            viewModel.startGame(mode: viewModel.gameMode)
                        },
                        onMainMenu: {
                            withAnimation {
                                selectedMode = nil
                            }
                        }
                    )
                    .transition(.opacity)
                }
            } else {
                // Main menu
                MenuView(selectedMode: $selectedMode)
                    .transition(.opacity)
                    .onChange(of: selectedMode) { _, newMode in
                        if let mode = newMode {
                            viewModel.startGame(mode: mode)
                        }
                    }
            }
        }
        .animation(.easeInOut(duration: 0.3), value: selectedMode)
        .preferredColorScheme(.dark)
        .onChange(of: viewModel.wantsQuitToMenu) { _, wantsQuit in
            if wantsQuit {
                withAnimation {
                    selectedMode = nil
                }
                viewModel.wantsQuitToMenu = false
            }
        }
    }
}
