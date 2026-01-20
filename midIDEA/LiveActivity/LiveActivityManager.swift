import ActivityKit
import Foundation

/// Manages Live Activities for Dynamic Island recording indicator
@MainActor
class LiveActivityManager: ObservableObject {
    static let shared = LiveActivityManager()

    private var currentActivity: Activity<RecordingActivityAttributes>?
    private var updateTimer: Timer?
    private var startTime: Date?
    private var currentAudioLevel: Float = 0

    private init() {}

    // MARK: - Public Methods

    /// Start a recording Live Activity for Dynamic Island
    func startRecordingActivity() {
        // Check if Live Activities are supported
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            print("Live Activities not enabled")
            return
        }

        // End any existing activity
        if currentActivity != nil {
            endRecordingActivity()
        }

        startTime = Date()

        let attributes = RecordingActivityAttributes(startTime: startTime!)
        let initialState = RecordingActivityAttributes.ContentState(
            elapsedTime: 0,
            isActive: true,
            audioLevel: 0
        )

        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: .init(state: initialState, staleDate: nil),
                pushType: nil
            )
            currentActivity = activity
            print("Started Live Activity: \(activity.id)")

            // Start update timer
            startUpdateTimer()
        } catch {
            print("Failed to start Live Activity: \(error)")
        }
    }

    /// Update the activity with new elapsed time and audio level
    func updateRecordingActivity(elapsedTime: TimeInterval, audioLevel: Float = 0) {
        guard let activity = currentActivity else { return }

        let state = RecordingActivityAttributes.ContentState(
            elapsedTime: elapsedTime,
            isActive: true,
            audioLevel: normalizeAudioLevel(audioLevel)
        )

        Task {
            await activity.update(.init(state: state, staleDate: nil))
        }
    }

    /// End the recording Live Activity
    func endRecordingActivity() {
        stopUpdateTimer()

        guard let activity = currentActivity else { return }

        let finalState = RecordingActivityAttributes.ContentState(
            elapsedTime: startTime.map { Date().timeIntervalSince($0) } ?? 0,
            isActive: false,
            audioLevel: 0
        )

        Task {
            await activity.end(
                .init(state: finalState, staleDate: nil),
                dismissalPolicy: .immediate
            )
            print("Ended Live Activity")
        }

        currentActivity = nil
        startTime = nil
    }

    /// Set the current audio level for visualization
    func setAudioLevel(_ level: Float) {
        currentAudioLevel = level
    }

    // MARK: - Private Methods

    private func startUpdateTimer() {
        updateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.timerTick()
            }
        }
    }

    private func stopUpdateTimer() {
        updateTimer?.invalidate()
        updateTimer = nil
    }

    private func timerTick() {
        guard let start = startTime else { return }
        let elapsed = Date().timeIntervalSince(start)
        updateRecordingActivity(elapsedTime: elapsed, audioLevel: currentAudioLevel)
    }

    /// Normalize dB audio level (-60 to 0) to 0-1 range
    private func normalizeAudioLevel(_ dbLevel: Float) -> Float {
        // Audio level comes in dB (-60 to 0 typically)
        // Convert to 0-1 range
        let minDb: Float = -60
        let maxDb: Float = 0
        let clamped = max(minDb, min(maxDb, dbLevel))
        return (clamped - minDb) / (maxDb - minDb)
    }
}
