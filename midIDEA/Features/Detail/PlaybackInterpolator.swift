import Foundation
import QuartzCore

/// Interpolates playback position for smooth 120Hz rendering from 10Hz AudioService updates.
/// Based on proven AudioInterpolator pattern from LiquidAudioVisualizer.
@MainActor
final class PlaybackInterpolator: ObservableObject {
    private var previousTime: TimeInterval = 0
    private var currentTime: TimeInterval = 0
    private var lastUpdateTimestamp: TimeInterval = 0
    private let updateInterval: TimeInterval = 0.1  // 10Hz from AudioService

    private var smoothedTime: TimeInterval = 0
    private var isPlaying: Bool = false

    /// Called when AudioService publishes new currentTime (10Hz)
    func updatePosition(_ time: TimeInterval, playing: Bool) {
        previousTime = currentTime
        currentTime = time
        lastUpdateTimestamp = CACurrentMediaTime()
        isPlaying = playing
    }

    /// Called every render frame (60-120Hz) - returns interpolated position
    func getInterpolatedTime(at renderTime: TimeInterval) -> TimeInterval {
        guard isPlaying else {
            smoothedTime = currentTime
            return currentTime
        }

        let now = CACurrentMediaTime()
        let elapsed = now - lastUpdateTimestamp

        // Smoothstep interpolation (same as AudioInterpolator)
        let t = min(max(elapsed / updateInterval, 0), 1.0)
        let eased = t * t * (3 - 2 * t)
        let interpolated = previousTime + (currentTime - previousTime) * eased

        // Light physics smoothing (less aggressive than audio to prevent lag)
        let smoothing: Double = 0.25
        smoothedTime += (interpolated - smoothedTime) * smoothing

        return smoothedTime
    }

    /// Reset state (called when seeking or playback stops)
    func reset(to time: TimeInterval = 0, playing: Bool = false) {
        previousTime = time
        currentTime = time
        smoothedTime = time
        lastUpdateTimestamp = CACurrentMediaTime()
        isPlaying = playing
    }
}
