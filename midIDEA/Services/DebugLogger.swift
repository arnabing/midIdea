import Foundation
import os.log

/// Centralized debug logging utility for midIDEA
/// Usage: DebugLogger.log("Button pressed", category: .ui, level: .debug)
@MainActor
final class DebugLogger {

    enum Category: String {
        case ui = "UI"
        case audio = "Audio"
        case animation = "Animation"
        case actionButton = "ActionButton"
        case recording = "Recording"
        case sharing = "Sharing"
        case transcription = "Transcription"
        case general = "General"
    }

    enum Level {
        case debug
        case info
        case warning
        case error

        var osLogType: OSLogType {
            switch self {
            case .debug: return .debug
            case .info: return .info
            case .warning: return .default
            case .error: return .error
            }
        }

        var emoji: String {
            switch self {
            case .debug: return "🔍"
            case .info: return "ℹ️"
            case .warning: return "⚠️"
            case .error: return "❌"
            }
        }
    }

    private static let subsystem = "com.mididea.app"

    /// Log a message with category and level
    static func log(
        _ message: String,
        category: Category = .general,
        level: Level = .debug,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        #if DEBUG
        let logger = Logger(subsystem: subsystem, category: category.rawValue)
        let fileName = (file as NSString).lastPathComponent
        let logMessage = "\(level.emoji) [\(fileName):\(line)] \(function): \(message)"

        switch level {
        case .debug:
            logger.debug("\(logMessage)")
        case .info:
            logger.info("\(logMessage)")
        case .warning:
            logger.warning("\(logMessage)")
        case .error:
            logger.error("\(logMessage)")
        }

        // Also print to console for easier debugging
        print("[\(category.rawValue)] \(logMessage)")
        #endif
    }

    /// Log animation state changes
    static func logAnimation(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, category: .animation, level: .debug, file: file, function: function, line: line)
    }

    /// Log Action Button events
    static func logActionButton(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, category: .actionButton, level: .info, file: file, function: function, line: line)
    }

    /// Log recording state changes
    static func logRecording(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, category: .recording, level: .info, file: file, function: function, line: line)
    }

    /// Log UI interactions
    static func logUI(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, category: .ui, level: .debug, file: file, function: function, line: line)
    }

    /// Log errors with detailed context
    static func logError(_ message: String, error: Error? = nil, file: String = #file, function: String = #function, line: Int = #line) {
        var fullMessage = message
        if let error = error {
            fullMessage += " | Error: \(error.localizedDescription)"
        }
        log(fullMessage, category: .general, level: .error, file: file, function: function, line: line)
    }
}
