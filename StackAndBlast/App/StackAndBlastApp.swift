import SwiftUI
import FirebaseCore

@main
struct StackAndBlastApp: App {

    init() {
        // Initialize Firebase Analytics (requires GoogleService-Info.plist in bundle)
        FirebaseApp.configure()

        // Apply saved settings to audio and haptic managers
        AudioManager.shared.setSoundEnabled(SettingsManager.shared.isSoundEnabled)
        HapticManager.shared.setHapticsEnabled(SettingsManager.shared.isHapticsEnabled)

        // Start listening for StoreKit transactions (IAP)
        StoreManager.shared.startTransactionListener()

        // Remember the first launch — the rating prompt waits a couple of days
        _ = ReviewPromptManager.shared
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
