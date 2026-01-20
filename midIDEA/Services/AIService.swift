import Foundation
import FoundationModels

/// On-device AI service using Apple's Foundation Models (iOS 26+)
/// Provides text summarization and key point extraction without network calls
@MainActor
class AIService: ObservableObject {
    static let shared = AIService()

    @Published var isAvailable = false
    @Published var isProcessing = false

    private init() {
        checkAvailability()
    }

    // MARK: - Availability

    func checkAvailability() {
        // Check if we can create a session
        Task {
            do {
                let model = SystemLanguageModel.default
                let availability = model.availability
                switch availability {
                case .available:
                    isAvailable = true
                default:
                    isAvailable = false
                }
            }
        }
    }

    // MARK: - Summarization

    /// Generate a concise summary of the transcript
    func summarize(_ text: String) async throws -> String {
        guard isAvailable else {
            throw AIServiceError.notAvailable
        }

        guard !text.isEmpty else {
            throw AIServiceError.emptyInput
        }

        isProcessing = true
        defer { isProcessing = false }

        let session = LanguageModelSession()

        let prompt = """
        Summarize this voice recording transcript in 2-3 sentences. Focus on the main topic and key points:

        \(text)
        """

        let response = try await session.respond(to: prompt)
        return response.content
    }

    /// Extract key points from the transcript
    func extractKeyPoints(_ text: String) async throws -> [String] {
        guard isAvailable else {
            throw AIServiceError.notAvailable
        }

        guard !text.isEmpty else {
            throw AIServiceError.emptyInput
        }

        isProcessing = true
        defer { isProcessing = false }

        let session = LanguageModelSession()

        let prompt = """
        Extract 3-5 key points from this voice recording transcript. Return each point on a new line starting with "• ":

        \(text)
        """

        let response = try await session.respond(to: prompt)

        // Parse bullet points from response
        let points = response.content
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { $0.hasPrefix("•") || $0.hasPrefix("-") || $0.hasPrefix("*") }
            .map { String($0.dropFirst()).trimmingCharacters(in: .whitespaces) }

        return points.isEmpty ? [response.content] : points
    }

    /// Generate a title suggestion for the recording
    func suggestTitle(_ text: String) async throws -> String {
        guard isAvailable else {
            throw AIServiceError.notAvailable
        }

        guard !text.isEmpty else {
            throw AIServiceError.emptyInput
        }

        isProcessing = true
        defer { isProcessing = false }

        let session = LanguageModelSession()

        let prompt = """
        Suggest a short, descriptive title (3-6 words) for this voice recording:

        \(text)
        """

        let response = try await session.respond(to: prompt)
        return response.content.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Generate summary with key points combined
    func generateInsights(_ text: String) async throws -> AIInsights {
        guard isAvailable else {
            throw AIServiceError.notAvailable
        }

        guard !text.isEmpty else {
            throw AIServiceError.emptyInput
        }

        isProcessing = true
        defer { isProcessing = false }

        let session = LanguageModelSession()

        let prompt = """
        Analyze this voice recording transcript and provide:
        1. A 1-2 sentence summary
        2. 3 key points (each on a new line starting with "• ")

        Transcript:
        \(text)
        """

        let response = try await session.respond(to: prompt)
        let content = response.content

        // Parse the response
        let lines = content.components(separatedBy: "\n").map { $0.trimmingCharacters(in: .whitespaces) }

        var summary = ""
        var keyPoints: [String] = []

        for line in lines {
            if line.hasPrefix("•") || line.hasPrefix("-") || line.hasPrefix("*") {
                let point = String(line.dropFirst()).trimmingCharacters(in: .whitespaces)
                if !point.isEmpty {
                    keyPoints.append(point)
                }
            } else if !line.isEmpty && summary.isEmpty && !line.lowercased().contains("key point") {
                summary = line
            }
        }

        // Fallback if parsing didn't work well
        if summary.isEmpty {
            summary = content
        }

        return AIInsights(summary: summary, keyPoints: keyPoints)
    }
}

// MARK: - Models

struct AIInsights {
    let summary: String
    let keyPoints: [String]
}

// MARK: - Errors

enum AIServiceError: LocalizedError {
    case notAvailable
    case emptyInput
    case processingFailed

    var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "Apple Intelligence is not available on this device"
        case .emptyInput:
            return "No text provided for analysis"
        case .processingFailed:
            return "Failed to process the text"
        }
    }
}
