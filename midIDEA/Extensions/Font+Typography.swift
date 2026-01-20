import SwiftUI

// MARK: - iOS 26 Typography System

/// Modern iOS 26 typography using SF Pro with consistent sizing and weights.
/// Uses the new system font features for optimal rendering on all devices.
extension Font {
    // MARK: - Display Fonts (Large headers)

    /// Large display title (34pt, bold, rounded)
    static let displayLarge = Font.system(size: 34, weight: .bold, design: .rounded)

    /// Medium display title (28pt, bold, rounded)
    static let displayMedium = Font.system(size: 28, weight: .bold, design: .rounded)

    /// Small display title (24pt, semibold, rounded)
    static let displaySmall = Font.system(size: 24, weight: .semibold, design: .rounded)

    // MARK: - Headline Fonts

    /// Primary headline (20pt, semibold, rounded)
    static let headlinePrimary = Font.system(size: 20, weight: .semibold, design: .rounded)

    /// Secondary headline (17pt, semibold, rounded)
    static let headlineSecondary = Font.system(size: 17, weight: .semibold, design: .rounded)

    // MARK: - Body Fonts

    /// Primary body text (17pt, regular, rounded)
    static let bodyPrimary = Font.system(size: 17, weight: .regular, design: .rounded)

    /// Secondary body text (15pt, regular, rounded)
    static let bodySecondary = Font.system(size: 15, weight: .regular, design: .rounded)

    /// Emphasized body text (15pt, medium, rounded)
    static let bodyEmphasized = Font.system(size: 15, weight: .medium, design: .rounded)

    // MARK: - Caption Fonts

    /// Primary caption (14pt, medium, rounded)
    static let captionPrimary = Font.system(size: 14, weight: .medium, design: .rounded)

    /// Secondary caption (13pt, regular, rounded)
    static let captionSecondary = Font.system(size: 13, weight: .regular, design: .rounded)

    /// Small caption (12pt, medium, rounded)
    static let captionSmall = Font.system(size: 12, weight: .medium, design: .rounded)

    // MARK: - Label Fonts

    /// Button label (16pt, semibold, rounded)
    static let buttonLabel = Font.system(size: 16, weight: .semibold, design: .rounded)

    /// Tag/badge label (13pt, semibold, rounded)
    static let tagLabel = Font.system(size: 13, weight: .semibold, design: .rounded)

    // MARK: - Monospaced Fonts (for time, durations, numbers)

    /// Large monospaced (24pt, semibold)
    static let monoLarge = Font.system(size: 24, weight: .semibold, design: .monospaced)

    /// Medium monospaced (17pt, medium)
    static let monoMedium = Font.system(size: 17, weight: .medium, design: .monospaced)

    /// Small monospaced (14pt, medium)
    static let monoSmall = Font.system(size: 14, weight: .medium, design: .monospaced)

    /// Tiny monospaced (12pt, medium)
    static let monoTiny = Font.system(size: 12, weight: .medium, design: .monospaced)
}

// MARK: - View Extension for Consistent Text Styling

extension View {
    /// Apply primary text styling with automatic foreground
    func textPrimary() -> some View {
        self.foregroundStyle(.white.opacity(0.9))
    }

    /// Apply secondary text styling
    func textSecondary() -> some View {
        self.foregroundStyle(.white.opacity(0.6))
    }

    /// Apply muted text styling
    func textMuted() -> some View {
        self.foregroundStyle(.white.opacity(0.4))
    }
}
