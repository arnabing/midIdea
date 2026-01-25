import Foundation

/// Shared container for App Groups file access
enum SharedContainer {
    /// App Group identifier
    static let appGroupIdentifier = SharedDefaults.appGroupIdentifier

    /// Shared container URL
    static var containerURL: URL {
        guard let url = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupIdentifier
        ) else {
            fatalError("App Group container not available: \(appGroupIdentifier)")
        }
        return url
    }

    /// Shared recordings directory
    static var recordingsDirectory: URL {
        let dir = containerURL.appendingPathComponent("Recordings", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// Shared temp directory for voice input audio
    static var tempAudioDirectory: URL {
        let dir = containerURL.appendingPathComponent("TempAudio", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// Get audio file URL in shared container
    static func audioFileURL(named fileName: String) -> URL {
        recordingsDirectory.appendingPathComponent(fileName)
    }

    /// Clean up temp audio files older than 1 hour
    static func cleanupTempAudio() {
        let fileManager = FileManager.default
        guard let files = try? fileManager.contentsOfDirectory(
            at: tempAudioDirectory,
            includingPropertiesForKeys: [.creationDateKey]
        ) else { return }

        let oneHourAgo = Date().addingTimeInterval(-3600)

        for file in files {
            guard let attrs = try? fileManager.attributesOfItem(atPath: file.path),
                  let creationDate = attrs[.creationDate] as? Date,
                  creationDate < oneHourAgo else { continue }
            try? fileManager.removeItem(at: file)
        }
    }
}
