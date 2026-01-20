import AppIntents
import Foundation

// MARK: - Toggle Recording Intent (Primary Action Button action)

/// The main intent for Action Button - toggles recording on/off
@available(iOS 17.0, *)
struct ToggleRecordingIntent: AppIntent {
    static var title: LocalizedStringResource = "Record Voice Note"
    static var description = IntentDescription("Start or stop a voice recording")

    /// Opens the app when triggered from Action Button
    static var openAppWhenRun: Bool = true

    /// Shows in Siri Suggestions and Spotlight
    static var isDiscoverable: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        NotificationCenter.default.post(
            name: .toggleRecordingFromIntent,
            object: nil
        )
        return .result()
    }
}

// MARK: - Start Recording Intent

@available(iOS 17.0, *)
struct StartRecordingIntent: AppIntent {
    static var title: LocalizedStringResource = "Start Recording"
    static var description = IntentDescription("Start a new voice recording")

    static var openAppWhenRun: Bool = true
    static var isDiscoverable: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        NotificationCenter.default.post(
            name: .startRecordingFromIntent,
            object: nil
        )
        return .result()
    }
}

// MARK: - Stop Recording Intent

@available(iOS 17.0, *)
struct StopRecordingIntent: AppIntent {
    static var title: LocalizedStringResource = "Stop Recording"
    static var description = IntentDescription("Stop the current recording")

    static var openAppWhenRun: Bool = true
    static var isDiscoverable: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        NotificationCenter.default.post(
            name: .stopRecordingFromIntent,
            object: nil
        )
        return .result()
    }
}

// MARK: - App Shortcuts Provider

/// Provides shortcuts that appear in Shortcuts app and can be assigned to Action Button
@available(iOS 17.0, *)
struct midIDEAShortcuts: AppShortcutsProvider {

    /// Update this when shortcuts change to force system refresh
    static var shortcutTileColor: ShortcutTileColor = .red

    static var appShortcuts: [AppShortcut] {
        // Primary shortcut - Toggle Recording (best for Action Button)
        AppShortcut(
            intent: ToggleRecordingIntent(),
            phrases: [
                "Record with \(.applicationName)",
                "Start recording with \(.applicationName)",
                "Voice note with \(.applicationName)",
                "New recording in \(.applicationName)"
            ],
            shortTitle: "Record",
            systemImageName: "waveform.circle.fill"
        )

        AppShortcut(
            intent: StartRecordingIntent(),
            phrases: [
                "Start \(.applicationName) recording",
                "Begin recording with \(.applicationName)"
            ],
            shortTitle: "Start",
            systemImageName: "record.circle"
        )

        AppShortcut(
            intent: StopRecordingIntent(),
            phrases: [
                "Stop \(.applicationName) recording",
                "End recording with \(.applicationName)"
            ],
            shortTitle: "Stop",
            systemImageName: "stop.circle"
        )
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let startRecordingFromIntent = Notification.Name("midIDEA.startRecording")
    static let stopRecordingFromIntent = Notification.Name("midIDEA.stopRecording")
    static let toggleRecordingFromIntent = Notification.Name("midIDEA.toggleRecording")
}
