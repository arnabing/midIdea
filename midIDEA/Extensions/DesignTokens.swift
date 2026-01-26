import SwiftUI

// MARK: - Design Tokens

/// Centralized design tokens for Figma alignment.
/// Update these values to match your Figma design specs.
enum DesignTokens {

    // MARK: - Colors

    enum Colors {
        // Background gradient (dark theme)
        static let backgroundDarkest = Color(hex: "050508")
        static let backgroundDark = Color(hex: "0A0A12")
        static let backgroundMedium = Color(hex: "0F0F1A")

        // Recording red
        static let recordingRed = Color.red
        static let recordingRedShadow = Color.red.opacity(0.5)

        // Text opacity levels
        static let textPrimary: Double = 0.9
        static let textSecondary: Double = 0.6
        static let textMuted: Double = 0.45
        static let textHint: Double = 0.35

        // Glass tint (for iOS 26 glass effects)
        static let glassTint = Color.white.opacity(0.1)
    }

    // MARK: - Spacing

    enum Spacing {
        static let xxxs: CGFloat = 4
        static let xxs: CGFloat = 6
        static let xs: CGFloat = 8
        static let sm: CGFloat = 10
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
        static let xxl: CGFloat = 24
        static let xxxl: CGFloat = 28
        static let huge: CGFloat = 60
    }

    // MARK: - Record Button

    enum RecordButton {
        // Outer glass container
        static let outerSize: CGFloat = 100

        // Inner shapes
        static let circleSize: CGFloat = 76       // Record state
        static let squareSize: CGFloat = 40       // Stop state
        static let squareCornerRadius: CGFloat = 12

        // Shadows
        static let circleShadowRadius: CGFloat = 14
        static let squareShadowRadius: CGFloat = 16
        static let shadowOpacity: Double = 0.5
    }

    // MARK: - Recording Overlay (MainContainerView)

    enum RecordingOverlay {
        // Button sizes
        static let closeButtonSize: CGFloat = 40
        static let recordButtonOuter: CGFloat = 72
        static let recordButtonInner: CGFloat = 52
        static let stopSquareSize: CGFloat = 28

        // Padding
        static let topPadding: CGFloat = 60
        static let bottomPadding: CGFloat = 80
        static let horizontalPadding: CGFloat = 20

        // Status pill
        static let statusDotSize: CGFloat = 8
        static let statusFontSize: CGFloat = 14
        static let timeFontSize: CGFloat = 18
    }

    // MARK: - Status Indicator

    enum StatusIndicator {
        static let dotSize: CGFloat = 12
        static let recFontSize: CGFloat = 14
    }

    // MARK: - Corner Radii

    enum CornerRadius {
        static let small: CGFloat = 8
        static let medium: CGFloat = 12
        static let large: CGFloat = 16
        static let xlarge: CGFloat = 20
        static let pill: CGFloat = 100
    }

    // MARK: - Icon Sizes

    enum IconSize {
        static let small: CGFloat = 12
        static let medium: CGFloat = 14
        static let large: CGFloat = 16
        static let xlarge: CGFloat = 20
        static let xxlarge: CGFloat = 24
    }

    // MARK: - Animation

    enum Animation {
        static let springResponse: Double = 0.4
        static let springDamping: Double = 0.7
        static let fastSpringResponse: Double = 0.18
        static let fastSpringDamping: Double = 0.68
    }

    // MARK: - Touch Targets

    enum TouchTarget {
        /// Minimum recommended touch target size (Apple HIG)
        static let minimum: CGFloat = 44
    }
}

// MARK: - Convenience View Modifiers

extension View {
    /// Apply standard horizontal padding
    func horizontalPadding(_ size: CGFloat = DesignTokens.Spacing.xxl) -> some View {
        self.padding(.horizontal, size)
    }

    /// Apply standard spring animation
    func standardSpring() -> some View {
        self.animation(
            .spring(
                response: DesignTokens.Animation.springResponse,
                dampingFraction: DesignTokens.Animation.springDamping
            ),
            value: UUID() // Placeholder, caller should provide actual value
        )
    }
}

// MARK: - Background Gradient

extension LinearGradient {
    /// Standard dark background gradient
    static var darkBackground: LinearGradient {
        LinearGradient(
            colors: [
                DesignTokens.Colors.backgroundDarkest,
                DesignTokens.Colors.backgroundDark,
                DesignTokens.Colors.backgroundMedium,
                DesignTokens.Colors.backgroundDark,
                DesignTokens.Colors.backgroundDarkest
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
