import AppIntents
import WidgetKit

/// App Intent that can be triggered from the Dynamic Island to stop recording
struct StopRecordingIntent: AppIntent {
    static var title: LocalizedStringResource = "Stop Recording"
    static var description = IntentDescription("Stops the current recording")

    func perform() async throws -> some IntentResult {
        // Use App Groups shared UserDefaults to signal main app
        let defaults = UserDefaults(suiteName: "group.com.mididea.shared")
        defaults?.set(true, forKey: "stopRecordingRequested")
        defaults?.synchronize()

        return .result()
    }
}
