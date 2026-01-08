import AppIntents
import Foundation

// MARK: - Start Recording Intent (Action Button - Single Tap)

@available(iOS 17.0, *)
struct StartRecordingIntent: AppIntent {
    static var title: LocalizedStringResource = "Start Recording"
    static var description = IntentDescription("Start a new voice recording with midIDEA")

    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        // Post notification that app should start recording
        await MainActor.run {
            NotificationCenter.default.post(
                name: .startRecordingFromIntent,
                object: nil
            )
        }
        return .result()
    }
}

// MARK: - Stop Recording Intent (Action Button - Double Tap)

@available(iOS 17.0, *)
struct StopRecordingIntent: AppIntent {
    static var title: LocalizedStringResource = "Stop Recording"
    static var description = IntentDescription("Stop the current recording")

    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        await MainActor.run {
            NotificationCenter.default.post(
                name: .stopRecordingFromIntent,
                object: nil
            )
        }
        return .result()
    }
}

// MARK: - Toggle Recording Intent (Alternative single action)

@available(iOS 17.0, *)
struct ToggleRecordingIntent: AppIntent {
    static var title: LocalizedStringResource = "Toggle Recording"
    static var description = IntentDescription("Start or stop recording")

    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        await MainActor.run {
            NotificationCenter.default.post(
                name: .toggleRecordingFromIntent,
                object: nil
            )
        }
        return .result()
    }
}

// MARK: - App Shortcuts Provider

@available(iOS 17.0, *)
struct midIDEAShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartRecordingIntent(),
            phrases: [
                "Start recording with \(.applicationName)",
                "Record a voice note with \(.applicationName)",
                "New recording in \(.applicationName)"
            ],
            shortTitle: "Record",
            systemImageName: "record.circle"
        )

        AppShortcut(
            intent: StopRecordingIntent(),
            phrases: [
                "Stop recording with \(.applicationName)",
                "End recording in \(.applicationName)"
            ],
            shortTitle: "Stop",
            systemImageName: "stop.circle"
        )

        AppShortcut(
            intent: ToggleRecordingIntent(),
            phrases: [
                "Toggle recording with \(.applicationName)"
            ],
            shortTitle: "Toggle",
            systemImageName: "record.circle"
        )
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let startRecordingFromIntent = Notification.Name("midIDEA.startRecording")
    static let stopRecordingFromIntent = Notification.Name("midIDEA.stopRecording")
    static let toggleRecordingFromIntent = Notification.Name("midIDEA.toggleRecording")
}
