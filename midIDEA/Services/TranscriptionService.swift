import Speech
import AVFoundation

actor TranscriptionService {
    static let shared = TranscriptionService()

    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))

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

    var isAvailable: Bool {
        speechRecognizer?.isAvailable ?? false
    }

    // MARK: - Transcription

    func transcribe(audioURL: URL) async throws -> String {
        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            throw TranscriptionError.notAvailable
        }

        guard isAuthorized else {
            throw TranscriptionError.notAuthorized
        }

        let request = SFSpeechURLRecognitionRequest(url: audioURL)
        request.shouldReportPartialResults = false
        request.requiresOnDeviceRecognition = true

        return try await withCheckedThrowingContinuation { continuation in
            recognizer.recognitionTask(with: request) { result, error in
                if let error = error {
                    continuation.resume(throwing: TranscriptionError.recognitionFailed(error))
                    return
                }

                guard let result = result else {
                    continuation.resume(throwing: TranscriptionError.noResult)
                    return
                }

                if result.isFinal {
                    continuation.resume(returning: result.bestTranscription.formattedString)
                }
            }
        }
    }

    // MARK: - Real-time Transcription (for future use)

    func transcribeRealtime(audioURL: URL, onPartialResult: @escaping (String) -> Void) async throws -> String {
        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            throw TranscriptionError.notAvailable
        }

        let request = SFSpeechURLRecognitionRequest(url: audioURL)
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = true

        return try await withCheckedThrowingContinuation { continuation in
            var finalResult: String?

            recognizer.recognitionTask(with: request) { result, error in
                if let error = error {
                    if finalResult == nil {
                        continuation.resume(throwing: TranscriptionError.recognitionFailed(error))
                    }
                    return
                }

                guard let result = result else { return }

                let text = result.bestTranscription.formattedString

                if result.isFinal {
                    finalResult = text
                    continuation.resume(returning: text)
                } else {
                    onPartialResult(text)
                }
            }
        }
    }
}

// MARK: - Errors

enum TranscriptionError: LocalizedError {
    case notAvailable
    case notAuthorized
    case noResult
    case recognitionFailed(Error)

    var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "Speech recognition is not available on this device."
        case .notAuthorized:
            return "Speech recognition is not authorized. Please enable it in Settings."
        case .noResult:
            return "No transcription result was returned."
        case .recognitionFailed(let error):
            return "Transcription failed: \(error.localizedDescription)"
        }
    }
}
