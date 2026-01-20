import ActivityKit
import Foundation

/// Attributes for the recording Live Activity displayed in the Dynamic Island.
/// This struct must be identical in both the main app and widget extension.
struct RecordingActivityAttributes: ActivityAttributes {
    /// Dynamic state that updates during recording
    public struct ContentState: Codable, Hashable {
        var elapsedTime: TimeInterval
        var isActive: Bool
        var audioLevel: Float  // 0-1 normalized level for waveform
    }

    /// Static attributes set when activity starts
    var startTime: Date
}
