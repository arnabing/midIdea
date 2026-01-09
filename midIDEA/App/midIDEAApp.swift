import SwiftUI
import AVFoundation

@main
struct midIDEAApp: App {
    @StateObject private var recordingStore = RecordingStore()
    @StateObject private var audioService = AudioService()

    init() {
        configureAudioSession()
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
}
