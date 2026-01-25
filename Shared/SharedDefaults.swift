import Foundation

/// Wrapper for App Groups shared UserDefaults
/// Used for communication between main app and keyboard extension
enum SharedDefaults {
    /// App Group identifier - must match entitlements in both targets
    static let appGroupIdentifier = "group.com.mididea.shared"

    /// Shared UserDefaults suite
    static var shared: UserDefaults {
        guard let defaults = UserDefaults(suiteName: appGroupIdentifier) else {
            fatalError("App Group not configured: \(appGroupIdentifier)")
        }
        return defaults
    }

    // MARK: - Keys

    enum Keys {
        /// Pending transcript to insert into keyboard
        static let pendingTranscript = "pendingTranscript"
        /// Context hint from keyboard (email, message, document, etc.)
        static let inputContext = "inputContext"
        /// Recent transcripts for quick re-insertion
        static let recentTranscripts = "recentTranscripts"
        /// Whether keyboard triggered voice input
        static let keyboardTriggeredVoiceInput = "keyboardTriggeredVoiceInput"
        /// Bundle ID of the app that was active when keyboard opened voice input
        static let sourceAppBundleId = "sourceAppBundleId"
        /// Timestamp of last voice input request
        static let lastVoiceInputRequest = "lastVoiceInputRequest"
    }

    // MARK: - Pending Transcript

    /// Save transcript to be inserted by keyboard
    static func setPendingTranscript(_ transcript: String) {
        shared.set(transcript, forKey: Keys.pendingTranscript)
    }

    /// Get and clear pending transcript
    static func consumePendingTranscript() -> String? {
        let transcript = shared.string(forKey: Keys.pendingTranscript)
        shared.removeObject(forKey: Keys.pendingTranscript)
        return transcript
    }

    /// Check if there's a pending transcript
    static var hasPendingTranscript: Bool {
        shared.string(forKey: Keys.pendingTranscript) != nil
    }

    // MARK: - Input Context

    /// Set context hint from keyboard
    static func setInputContext(_ context: InputContext) {
        shared.set(context.rawValue, forKey: Keys.inputContext)
    }

    /// Get input context
    static func getInputContext() -> InputContext {
        guard let raw = shared.string(forKey: Keys.inputContext),
              let context = InputContext(rawValue: raw) else {
            return .general
        }
        return context
    }

    // MARK: - Recent Transcripts

    /// Maximum number of recent transcripts to keep
    private static let maxRecentTranscripts = 10

    /// Add transcript to recents
    static func addRecentTranscript(_ transcript: String) {
        var recents = getRecentTranscripts()
        // Remove if already exists
        recents.removeAll { $0 == transcript }
        // Add to front
        recents.insert(transcript, at: 0)
        // Trim to max
        if recents.count > maxRecentTranscripts {
            recents = Array(recents.prefix(maxRecentTranscripts))
        }
        shared.set(recents, forKey: Keys.recentTranscripts)
    }

    /// Get recent transcripts
    static func getRecentTranscripts() -> [String] {
        shared.stringArray(forKey: Keys.recentTranscripts) ?? []
    }

    /// Clear recent transcripts
    static func clearRecentTranscripts() {
        shared.removeObject(forKey: Keys.recentTranscripts)
    }

    // MARK: - Voice Input State

    /// Mark that keyboard triggered voice input
    static func setKeyboardTriggeredVoiceInput(_ triggered: Bool, sourceApp: String? = nil) {
        shared.set(triggered, forKey: Keys.keyboardTriggeredVoiceInput)
        if let sourceApp = sourceApp {
            shared.set(sourceApp, forKey: Keys.sourceAppBundleId)
        }
        shared.set(Date().timeIntervalSince1970, forKey: Keys.lastVoiceInputRequest)
    }

    /// Check if voice input was triggered by keyboard
    static func wasKeyboardTriggeredVoiceInput() -> Bool {
        // Only valid for 30 seconds
        let timestamp = shared.double(forKey: Keys.lastVoiceInputRequest)
        let elapsed = Date().timeIntervalSince1970 - timestamp
        guard elapsed < 30 else {
            clearVoiceInputState()
            return false
        }
        return shared.bool(forKey: Keys.keyboardTriggeredVoiceInput)
    }

    /// Get source app bundle ID
    static func getSourceAppBundleId() -> String? {
        shared.string(forKey: Keys.sourceAppBundleId)
    }

    /// Clear voice input state
    static func clearVoiceInputState() {
        shared.removeObject(forKey: Keys.keyboardTriggeredVoiceInput)
        shared.removeObject(forKey: Keys.sourceAppBundleId)
        shared.removeObject(forKey: Keys.lastVoiceInputRequest)
    }
}

// MARK: - Input Context

/// Context hint for AI formatting
enum InputContext: String, Codable {
    case email
    case message
    case notes
    case document
    case code
    case search
    case general

    /// User-friendly description
    var description: String {
        switch self {
        case .email: return "Email"
        case .message: return "Message"
        case .notes: return "Notes"
        case .document: return "Document"
        case .code: return "Code"
        case .search: return "Search"
        case .general: return "General"
        }
    }

    /// AI formatting style
    var formattingStyle: FormattingStyle {
        switch self {
        case .email: return .formal
        case .message: return .casual
        case .notes: return .structured
        case .document: return .formal
        case .code: return .technical
        case .search: return .minimal
        case .general: return .balanced
        }
    }
}

/// AI formatting style
enum FormattingStyle {
    case formal      // Professional language, proper punctuation
    case casual      // Relaxed, may include contractions
    case structured  // Bullet points, clear paragraphs
    case technical   // Preserve technical terms, no auto-formatting
    case minimal     // Minimal changes, just punctuation
    case balanced    // Default balanced formatting
}
