import SwiftUI

@main
struct StackAndBlastApp: App {

    init() {
        // Initialize Google Mobile Ads SDK and preload first rewarded ad
        AdManager.shared.configure()

        // Apply saved settings to audio and haptic managers
        AudioManager.shared.setSoundEnabled(SettingsManager.shared.isSoundEnabled)
        HapticManager.shared.setHapticsEnabled(SettingsManager.shared.isHapticsEnabled)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
