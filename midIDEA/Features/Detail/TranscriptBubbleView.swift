import SwiftUI

/// iMessage-style transcript bubble with red left border - Light mode
struct TranscriptBubbleView: View {
    let recording: Recording

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Title label
            Text(recording.displayTitle)
                .font(.captionPrimary)
                .foregroundStyle(.secondary)

            // Content bubble
            HStack(spacing: 0) {
                // Red left border accent
                Rectangle()
                    .fill(Color.red)
                    .frame(width: 4)

                // Content area
                contentView
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)
            }
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.08), radius: 8, y: 2)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    @ViewBuilder
    private var contentView: some View {
        switch recording.transcriptionStatus {
        case .completed:
            if let transcript = recording.transcript, !transcript.isEmpty {
                Text(transcript)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .lineSpacing(6)
                    .textSelection(.enabled)
            } else {
                emptyTranscriptView
            }

        case .inProgress:
            transcribingView

        case .failed:
            failedView

        case .pending:
            pendingView
        }
    }

    private var emptyTranscriptView: some View {
        VStack(spacing: 12) {
            Image(systemName: "text.bubble")
                .font(.system(size: 32))
                .foregroundStyle(.secondary)

            Text("No transcript available")
                .font(.body)
                .foregroundStyle(.secondary)

            Text("The recording may be too short or unclear")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }

    private var transcribingView: some View {
        ThinkingGlimmer()
    }

    private var failedView: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 32))
                .foregroundStyle(.orange)

            Text("Transcription failed")
                .font(.body)
                .foregroundStyle(.secondary)

            Text("Tap to retry")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }

    private var pendingView: some View {
        VStack(spacing: 12) {
            Image(systemName: "clock")
                .font(.system(size: 32))
                .foregroundStyle(.secondary)

            Text("Waiting to transcribe")
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }
}

#Preview("Completed") {
    TranscriptBubbleView(
        recording: {
            var r = Recording(duration: 125, audioFileName: "test.m4a")
            r.transcript = "I have a dream that one day this nation will rise up and live out the true meaning of its creed: We hold these truths to be self-evident, that all men are created equal.\n\nI have a dream that one day on the red hills of Georgia, the sons of former slaves and the sons of former slave owners will be able to sit down together at the table of brotherhood."
            r.transcriptionStatus = .completed
            return r
        }()
    )
    .padding()
}

#Preview("Transcribing") {
    TranscriptBubbleView(
        recording: {
            var r = Recording(duration: 125, audioFileName: "test.m4a")
            r.transcriptionStatus = .inProgress
            return r
        }()
    )
    .padding()
}

// MARK: - Shimmer Modifier

/// Creates a shimmer effect by animating a gradient mask across the content
struct Shimmer: ViewModifier {
    @State private var phase: CGFloat = -1

    var duration: Double
    var bounce: Bool

    init(duration: Double = 1.5, bounce: Bool = false) {
        self.duration = duration
        self.bounce = bounce
    }

    func body(content: Content) -> some View {
        content
            .mask(
                LinearGradient(
                    gradient: Gradient(stops: [
                        .init(color: .black.opacity(0.4), location: phase - 0.3),
                        .init(color: .black, location: phase),
                        .init(color: .black.opacity(0.4), location: phase + 0.3)
                    ]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .onAppear {
                withAnimation(.linear(duration: duration).repeatForever(autoreverses: bounce)) {
                    phase = 2
                }
            }
    }
}

extension View {
    /// Applies a shimmer animation effect
    func shimmering(duration: Double = 1.5, bounce: Bool = false) -> some View {
        modifier(Shimmer(duration: duration, bounce: bounce))
    }
}

// MARK: - Thinking Glimmer Component

/// Claude-like thinking indicator with shimmer effect and rotating phrases
struct ThinkingGlimmer: View {
    @State private var phraseIndex = 0
    @State private var phraseOpacity: Double = 1.0

    private let phrases = [
        "Transcribing...",
        "Listening closely...",
        "Processing audio...",
        "Understanding...",
        "Analyzing speech...",
        "Decoding words...",
        "Piecing it together...",
        "Almost there..."
    ]

    var body: some View {
        VStack(spacing: 16) {
            // Shimmer text
            Text(phrases[phraseIndex])
                .font(.body)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
                .shimmering(duration: 1.8)
                .opacity(phraseOpacity)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .onAppear {
            startPhraseRotation()
        }
    }

    private func startPhraseRotation() {
        Timer.scheduledTimer(withTimeInterval: 2.5, repeats: true) { _ in
            // Fade out
            withAnimation(.easeOut(duration: 0.3)) {
                phraseOpacity = 0
            }

            // Change phrase and fade in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                phraseIndex = (phraseIndex + 1) % phrases.count
                withAnimation(.easeIn(duration: 0.3)) {
                    phraseOpacity = 1
                }
            }
        }
    }
}

#Preview("Thinking Glimmer") {
    ThinkingGlimmer()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding()
}
