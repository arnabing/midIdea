import ActivityKit
import Foundation

/// Activity mode - recording or playback
enum ActivityMode: String, Codable, Hashable {
    case recording
    case playback
}

/// Attributes for the recording/playback Live Activity displayed in the Dynamic Island.
/// This struct must be identical in both the main app and widget extension.
struct RecordingActivityAttributes: ActivityAttributes {
    /// Dynamic state that updates during recording/playback
    public struct ContentState: Codable, Hashable {
        var elapsedTime: TimeInterval
        var isActive: Bool
        var audioLevel: Float  // 0-1 normalized level for waveform
        var mode: ActivityMode
        var totalDuration: TimeInterval?  // Only for playback
        var title: String?  // Recording title for playback
    }

    /// Static attributes set when activity starts
    var startTime: Date
    var mode: ActivityMode
}
