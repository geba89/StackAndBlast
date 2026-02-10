import SwiftUI

@main
struct StackAndBlastApp: App {

    init() {
        // Initialize Google Mobile Ads SDK and preload first rewarded ad
        AdManager.shared.configure()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
