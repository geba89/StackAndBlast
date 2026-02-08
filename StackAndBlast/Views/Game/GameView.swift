import SwiftUI
import SpriteKit

/// SwiftUI wrapper that hosts the SpriteKit GameScene.
struct GameView: View {
    @Bindable var viewModel: GameViewModel

    /// The SpriteKit scene instance.
    private var scene: GameScene {
        let scene = GameScene()
        scene.size = CGSize(width: 390, height: 844) // iPhone 14 reference size
        scene.scaleMode = .aspectFill
        return scene
    }

    var body: some View {
        ZStack {
            // SpriteKit game scene
            SpriteView(scene: scene)
                .ignoresSafeArea()

            // HUD overlay
            VStack {
                // Score bar
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("SCORE")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundStyle(.gray)
                        Text("\(viewModel.engine.score)")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                    }

                    Spacer()

                    Button {
                        // TODO: Pause action
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
        }
    }
}
