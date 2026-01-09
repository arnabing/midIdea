import Foundation
import Combine

@MainActor
class RecordingStore: ObservableObject {
    @Published var recordings: [Recording] = []
    @Published var currentRecording: Recording?

    private let storageKey = "midIDEA.recordings"

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

    func saveRecordings() {
        guard let encoded = try? JSONEncoder().encode(recordings) else { return }
        UserDefaults.standard.set(encoded, forKey: storageKey)
    }

    func addRecording(_ recording: Recording) {
        recordings.insert(recording, at: 0)
        saveRecordings()
    }

    func updateRecording(_ recording: Recording) {
        if let index = recordings.firstIndex(where: { $0.id == recording.id }) {
            recordings[index] = recording
            saveRecordings()
        }
    }

    func deleteRecording(_ recording: Recording) {
        // Delete audio file
        try? FileManager.default.removeItem(at: recording.audioURL)

        // Remove from list
        recordings.removeAll { $0.id == recording.id }
        saveRecordings()
    }

    func deleteRecording(at offsets: IndexSet) {
        for index in offsets {
            let recording = recordings[index]
            try? FileManager.default.removeItem(at: recording.audioURL)
        }
        recordings.remove(atOffsets: offsets)
        saveRecordings()
    }
}
