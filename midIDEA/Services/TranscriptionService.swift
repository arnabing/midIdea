import Speech
import AVFoundation

/// Modern transcription service using iOS 26+ SpeechAnalyzer API.
/// Fully on-device, faster than Whisper, with automatic model management.
actor TranscriptionService {
    static let shared = TranscriptionService()

    private init() {}

    // MARK: - Authorization

    func requestAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }

    var isAuthorized: Bool {
        SFSpeechRecognizer.authorizationStatus() == .authorized
    }

    // MARK: - iOS 26+ Modern Transcription

    func transcribe(audioURL: URL) async throws -> String {
        // Verify file exists
        guard FileManager.default.fileExists(atPath: audioURL.path) else {
            throw TranscriptionError.fileNotFound
        }

        let locale = Locale.current

        // Try modern SpeechTranscriber first, fall back to DictationTranscriber
        do {
            return try await transcribeWithSpeechTranscriber(audioURL: audioURL, locale: locale)
        } catch {
            // Fall back to DictationTranscriber for unsupported devices/languages
            return try await transcribeWithDictation(audioURL: audioURL, locale: locale)
        }
    }

    // MARK: - SpeechTranscriber (Modern, On-Device)

    private func transcribeWithSpeechTranscriber(audioURL: URL, locale: Locale) async throws -> String {
        // Create transcriber with options for voice memos
        let transcriber = SpeechTranscriber(
            locale: locale,
            transcriptionOptions: [],
            reportingOptions: [],
            attributeOptions: []
        )

        // Ensure language model is installed
        try await ensureModelInstalled(for: transcriber, locale: locale)

        // Create analyzer with the transcriber module
        let analyzer = SpeechAnalyzer(modules: [transcriber])

        // Load audio file
        let audioFile = try AVAudioFile(forReading: audioURL)

        // Start processing
        try await analyzer.start(inputAudioFile: audioFile, finishAfterFile: true)

        // Collect results from async stream
        var transcript = ""
        for try await result in transcriber.results {
            transcript += String(result.text.characters)
        }

        return transcript
    }

    // MARK: - DictationTranscriber (Fallback)

    private func transcribeWithDictation(audioURL: URL, locale: Locale) async throws -> String {
        let transcriber = DictationTranscriber(
            locale: locale,
            contentHints: [],
            transcriptionOptions: [],
            reportingOptions: [],
            attributeOptions: []
        )

        let analyzer = SpeechAnalyzer(modules: [transcriber])
        let audioFile = try AVAudioFile(forReading: audioURL)

        try await analyzer.start(inputAudioFile: audioFile, finishAfterFile: true)

        var transcript = ""
        for try await result in transcriber.results {
            transcript += String(result.text.characters)
        }

        return transcript
    }

    // MARK: - Model Management

    private func ensureModelInstalled(for transcriber: SpeechTranscriber, locale: Locale) async throws {
        // Check if locale is already installed
        let installed = await SpeechTranscriber.installedLocales
        let isInstalled = installed.contains { $0.identifier == locale.identifier }

        if !isInstalled {
            // Request and download the model
            if let request = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
                try await request.downloadAndInstall()
            }
        }
    }

    // MARK: - Real-time Transcription

    func transcribeRealtime(audioURL: URL, onPartialResult: @escaping (String) -> Void) async throws -> String {
        let locale = Locale.current

        // Use SpeechTranscriber with volatile results for real-time updates
        let transcriber = SpeechTranscriber(
            locale: locale,
            transcriptionOptions: [],
            reportingOptions: [.volatileResults],
            attributeOptions: []
        )

        try await ensureModelInstalled(for: transcriber, locale: locale)

        let analyzer = SpeechAnalyzer(modules: [transcriber])
        let audioFile = try AVAudioFile(forReading: audioURL)

        try await analyzer.start(inputAudioFile: audioFile, finishAfterFile: true)

        var finalTranscript = ""
        for try await result in transcriber.results {
            let text = String(result.text.characters)
            if result.resultsFinalizationTime.isValid {
                finalTranscript += text
            } else {
                onPartialResult(text)
            }
        }

        return finalTranscript
    }
}

// MARK: - Errors

enum TranscriptionError: LocalizedError {
    case notAvailable
    case notAuthorized
    case noResult
    case fileNotFound
    case timeout
    case modelDownloadFailed
    case recognitionFailed(Error)

    var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "Speech recognition is not available on this device."
        case .notAuthorized:
            return "Speech recognition is not authorized. Please enable it in Settings."
        case .noResult:
            return "No transcription result was returned."
        case .fileNotFound:
            return "Audio file not found."
        case .timeout:
            return "Transcription timed out. Please try again."
        case .modelDownloadFailed:
            return "Failed to download language model."
        case .recognitionFailed(let error):
            return "Transcription failed: \(error.localizedDescription)"
        }
    }
}
