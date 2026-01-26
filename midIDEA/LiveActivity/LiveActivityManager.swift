import ActivityKit
import Foundation

/// Manages Live Activities for Dynamic Island recording/playback indicator
@MainActor
class LiveActivityManager: ObservableObject {
    static let shared = LiveActivityManager()

    private var currentActivity: Activity<RecordingActivityAttributes>?
    private var updateTimer: Timer?
    private var startTime: Date?
    private var currentAudioLevel: Float = 0
    private var currentMode: ActivityMode = .recording
    private var playbackDuration: TimeInterval = 0
    private var playbackTitle: String?

    private init() {}

    // MARK: - Recording Methods

    /// Start a recording Live Activity for Dynamic Island
    func startRecordingActivity() {
        // Debug: Check authorization status
        let authInfo = ActivityAuthorizationInfo()
        print("[LiveActivity] Authorization check:")
        print("  - areActivitiesEnabled: \(authInfo.areActivitiesEnabled)")
        print("  - frequentPushesEnabled: \(authInfo.frequentPushesEnabled)")

        // Check if Live Activities are supported
        guard authInfo.areActivitiesEnabled else {
            print("[LiveActivity] ERROR: Live Activities not enabled by user")
            return
        }

        // End any existing activity
        if currentActivity != nil {
            print("[LiveActivity] Ending existing activity before starting new one")
            endActivity()
        }

        startTime = Date()
        currentMode = .recording

        let attributes = RecordingActivityAttributes(startTime: startTime!, mode: .recording)
        let initialState = RecordingActivityAttributes.ContentState(
            elapsedTime: 0,
            isActive: true,
            audioLevel: 0,
            mode: .recording,
            totalDuration: nil,
            title: nil
        )

        print("[LiveActivity] Requesting Live Activity...")

        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: .init(state: initialState, staleDate: nil),
                pushType: nil
            )
            currentActivity = activity
            print("[LiveActivity] SUCCESS - Started Recording Live Activity: \(activity.id)")

            // Start update timer
            startUpdateTimer()
        } catch let error as ActivityAuthorizationError {
            print("[LiveActivity] AUTHORIZATION ERROR: \(error.localizedDescription)")
        } catch {
            print("[LiveActivity] FAILED to start Live Activity:")
            print("  - Error: \(error)")
            print("  - Localized: \(error.localizedDescription)")
        }
    }

    /// End the recording Live Activity
    func endRecordingActivity() {
        endActivity()
    }

    // MARK: - Playback Methods

    /// Start a playback Live Activity for Dynamic Island
    func startPlaybackActivity(title: String, duration: TimeInterval) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            print("Live Activities not enabled")
            return
        }

        // End any existing activity
        if currentActivity != nil {
            endActivity()
        }

        startTime = Date()
        currentMode = .playback
        playbackDuration = duration
        playbackTitle = title

        let attributes = RecordingActivityAttributes(startTime: startTime!, mode: .playback)
        let initialState = RecordingActivityAttributes.ContentState(
            elapsedTime: 0,
            isActive: true,
            audioLevel: 0,
            mode: .playback,
            totalDuration: duration,
            title: title
        )

        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: .init(state: initialState, staleDate: nil),
                pushType: nil
            )
            currentActivity = activity
            print("Started Playback Live Activity: \(activity.id)")

            // Start update timer
            startUpdateTimer()
        } catch {
            print("Failed to start Playback Live Activity: \(error)")
        }
    }

    /// Update playback progress
    func updatePlaybackProgress(_ currentTime: TimeInterval) {
        guard let activity = currentActivity, currentMode == .playback else { return }

        let state = RecordingActivityAttributes.ContentState(
            elapsedTime: currentTime,
            isActive: true,
            audioLevel: currentAudioLevel,
            mode: .playback,
            totalDuration: playbackDuration,
            title: playbackTitle
        )

        Task {
            await activity.update(.init(state: state, staleDate: nil))
        }
    }

    /// End the playback Live Activity
    func endPlaybackActivity() {
        endActivity()
    }

    // MARK: - Shared Methods

    /// Set the current audio level for visualization
    func setAudioLevel(_ level: Float) {
        currentAudioLevel = level
    }

    /// End any active Live Activity
    func endActivity() {
        stopUpdateTimer()

        guard let activity = currentActivity else { return }

        let finalState = RecordingActivityAttributes.ContentState(
            elapsedTime: startTime.map { Date().timeIntervalSince($0) } ?? 0,
            isActive: false,
            audioLevel: 0,
            mode: currentMode,
            totalDuration: currentMode == .playback ? playbackDuration : nil,
            title: playbackTitle
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
        playbackTitle = nil
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

        if currentMode == .recording {
            updateRecordingActivity(elapsedTime: elapsed, audioLevel: currentAudioLevel)
        }
        // Note: Playback progress is updated externally via updatePlaybackProgress
    }

    /// Update the recording activity with new elapsed time and audio level
    private func updateRecordingActivity(elapsedTime: TimeInterval, audioLevel: Float = 0) {
        guard let activity = currentActivity, currentMode == .recording else { return }

        let state = RecordingActivityAttributes.ContentState(
            elapsedTime: elapsedTime,
            isActive: true,
            audioLevel: normalizeAudioLevel(audioLevel),
            mode: .recording,
            totalDuration: nil,
            title: nil
        )

        Task {
            await activity.update(.init(state: state, staleDate: nil))
        }
    }

    /// Normalize dB audio level (-60 to 0) to 0-1 range
    private func normalizeAudioLevel(_ dbLevel: Float) -> Float {
        let minDb: Float = -60
        let maxDb: Float = 0
        let clamped = max(minDb, min(maxDb, dbLevel))
        return (clamped - minDb) / (maxDb - minDb)
    }
}
