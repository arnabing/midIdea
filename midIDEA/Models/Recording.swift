import Foundation

struct Recording: Identifiable, Codable, Hashable {
    let id: UUID
    let createdAt: Date
    var duration: TimeInterval
    let audioFileName: String
    var transcript: String?
    var transcriptionStatus: TranscriptionStatus

    // Apple Intelligence generated insights
    var aiSummary: String?
    var aiKeyPoints: [String]?

    // Session linking for resume functionality
    var sessionId: UUID?

    // Cached waveform data for instant display
    var waveformSamples: [Float]?

    init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        duration: TimeInterval = 0,
        audioFileName: String,
        transcript: String? = nil,
        transcriptionStatus: TranscriptionStatus = .pending,
        aiSummary: String? = nil,
        aiKeyPoints: [String]? = nil,
        sessionId: UUID? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.duration = duration
        self.audioFileName = audioFileName
        self.transcript = transcript
        self.transcriptionStatus = transcriptionStatus
        self.aiSummary = aiSummary
        self.aiKeyPoints = aiKeyPoints
        self.sessionId = sessionId
    }

    var audioURL: URL {
        Recording.recordingsDirectory.appendingPathComponent(audioFileName)
    }

    var waveformURL: URL {
        Recording.recordingsDirectory
            .appendingPathComponent("\(id.uuidString).waveform")
    }

    var displayTitle: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: createdAt)
    }

    var durationFormatted: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    var formattedDuration: String {
        durationFormatted
    }

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: createdAt)
    }

    /// Convenience accessor for AI summary
    var summary: String? {
        get { aiSummary }
        set { aiSummary = newValue }
    }

    /// Save waveform samples to disk
    func saveWaveform(_ samples: [Float]) throws {
        let data = try JSONEncoder().encode(samples)
        try data.write(to: waveformURL)
    }

    /// Load waveform samples from disk
    func loadWaveform() -> [Float]? {
        guard FileManager.default.fileExists(atPath: waveformURL.path) else {
            return nil
        }
        guard let data = try? Data(contentsOf: waveformURL) else {
            return nil
        }
        return try? JSONDecoder().decode([Float].self, from: data)
    }

    static var recordingsDirectory: URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let recordingsDir = paths[0].appendingPathComponent("Recordings")

        if !FileManager.default.fileExists(atPath: recordingsDir.path) {
            try? FileManager.default.createDirectory(at: recordingsDir, withIntermediateDirectories: true)
        }

        return recordingsDir
    }
}

enum TranscriptionStatus: String, Codable {
    case pending
    case inProgress
    case completed
    case failed
}
