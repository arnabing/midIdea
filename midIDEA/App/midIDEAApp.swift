import SwiftUI
import AVFoundation
import AppIntents

@main
struct midIDEAApp: App {
    @StateObject private var recordingStore = RecordingStore()
    @StateObject private var audioService = AudioService()

    init() {
        configureAudioSession()
        registerAppShortcuts()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(recordingStore)
                .environmentObject(audioService)
        }
    }

    private func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try session.setActive(true)
        } catch {
            print("Failed to configure audio session: \(error)")
        }
    }

    /// Register App Shortcuts with the system for Siri, Spotlight, and Action Button
    private func registerAppShortcuts() {
        if #available(iOS 17.0, *) {
            midIDEAShortcuts.updateAppShortcutParameters()
            print("App Shortcuts registered successfully")
        }
    }
}
