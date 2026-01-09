import UIKit
import CoreHaptics

class HapticService {
    static let shared = HapticService()

    private var engine: CHHapticEngine?

    private init() {
        setupHapticEngine()
    }

    private func setupHapticEngine() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }

        do {
            engine = try CHHapticEngine()
            try engine?.start()
        } catch {
            print("Haptic engine failed to start: \(error)")
        }
    }

    // MARK: - Recording Haptics

    func playRecordStart() {
        let impact = UIImpactFeedbackGenerator(style: .heavy)
        impact.impactOccurred()
    }

    func playRecordStop() {
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()
    }

    func playCountdownTick() {
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()
    }

    func playSaveSuccess() {
        let notification = UINotificationFeedbackGenerator()
        notification.notificationOccurred(.success)
    }

    func playButtonPress() {
        let impact = UIImpactFeedbackGenerator(style: .rigid)
        impact.impactOccurred(intensity: 0.6)
    }

    func playDiscardWarning() {
        let notification = UINotificationFeedbackGenerator()
        notification.notificationOccurred(.warning)
    }

    // MARK: - Custom Haptic Patterns

    func playTapeMotorStart() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics,
              let engine = engine else { return }

        var events: [CHHapticEvent] = []

        // Ramp up motor feel
        for i in 0..<5 {
            let intensity = Float(i + 1) / 5.0
            let event = CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.3)
                ],
                relativeTime: Double(i) * 0.05
            )
            events.append(event)
        }

        do {
            let pattern = try CHHapticPattern(events: events, parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            print("Failed to play haptic pattern: \(error)")
        }
    }
}
