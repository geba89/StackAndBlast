import CoreHaptics
import UIKit

/// Manages haptic feedback using Core Haptics (GDD section 5.2).
///
/// Haptic events: light tap on pickup, medium impact on placement,
/// heavy impact on blast, notification pulse on cascade combos.
final class HapticManager {

    static let shared = HapticManager()

    private var engine: CHHapticEngine?
    private var isHapticsEnabled = true

    private init() {
        prepareEngine()
    }

    // MARK: - Public API

    func setHapticsEnabled(_ enabled: Bool) {
        isHapticsEnabled = enabled
    }

    /// Light tap when picking up a piece.
    func playPickup() {
        guard isHapticsEnabled else { return }
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }

    /// Medium impact when placing a piece.
    func playPlacement() {
        guard isHapticsEnabled else { return }
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }

    /// Heavy impact on blast/explosion.
    func playBlast() {
        guard isHapticsEnabled else { return }
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.impactOccurred()
    }

    /// Notification pulse on cascade combos.
    func playCascade() {
        guard isHapticsEnabled else { return }
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }

    // MARK: - Private

    private func prepareEngine() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        do {
            engine = try CHHapticEngine()
            try engine?.start()
        } catch {
            // Haptics unavailable on this device — fail silently
        }
    }
}
