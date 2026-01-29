import Foundation
import Combine

@MainActor
class RecordingStore: ObservableObject {
    @Published var recordings: [Recording] = []
    @Published var currentRecording: Recording?

    private let storageKey = "midIDEA.recordings"
    private var saveTask: Task<Void, Never>?  // Track background save task

    init() {
        loadRecordings()
    }

    func loadRecordings() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([Recording].self, from: data) else {
            return
        }
        recordings = decoded.sorted { $0.createdAt > $1.createdAt }
    }

    /// Debounced background save - doesn't block UI
    private func scheduleSave() {
        saveTask?.cancel()  // Cancel pending save

        let recordingsSnapshot = recordings  // Capture current state

        saveTask = Task.detached(priority: .utility) {
            // Debounce: wait 500ms for more changes
            try? await Task.sleep(for: .milliseconds(500))

            guard !Task.isCancelled else { return }

            // Background JSON encode + UserDefaults write
            guard let encoded = try? JSONEncoder().encode(recordingsSnapshot) else { return }
            UserDefaults.standard.set(encoded, forKey: "midIDEA.recordings")
        }
    }

    /// Force immediate save (called when app backgrounds)
    func forceSave() async {
        saveTask?.cancel()  // Cancel debounced save

        let recordingsSnapshot = recordings

        await Task.detached(priority: .userInitiated) {
            guard let encoded = try? JSONEncoder().encode(recordingsSnapshot) else { return }
            UserDefaults.standard.set(encoded, forKey: "midIDEA.recordings")
        }.value
    }

    func addRecording(_ recording: Recording) {
        recordings.insert(recording, at: 0)
        scheduleSave()  // Non-blocking background save
    }

    func updateRecording(_ recording: Recording) {
        if let index = recordings.firstIndex(where: { $0.id == recording.id }) {
            recordings[index] = recording
            scheduleSave()  // Non-blocking background save
        }
    }

    func deleteRecording(_ recording: Recording) {
        // Delete audio file
        try? FileManager.default.removeItem(at: recording.audioURL)

        // Delete waveform file
        try? FileManager.default.removeItem(at: recording.waveformURL)

        // Remove from list
        recordings.removeAll { $0.id == recording.id }
        scheduleSave()  // Non-blocking background save
    }

    func deleteRecording(at offsets: IndexSet) {
        for index in offsets {
            let recording = recordings[index]
            try? FileManager.default.removeItem(at: recording.audioURL)
            try? FileManager.default.removeItem(at: recording.waveformURL)
        }
        recordings.remove(atOffsets: offsets)
        scheduleSave()  // Non-blocking background save
    }
}
