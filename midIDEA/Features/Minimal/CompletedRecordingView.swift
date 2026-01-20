import SwiftUI

/// Unified view for displaying a completed recording.
/// Used both after recording stops and when selecting from recordings list.
/// Follows iOS 26 Voice Memos pattern: plain text content, glass only on controls.
struct CompletedRecordingView: View {
    let recording: Recording
    let onNewRecording: () -> Void
    let onResume: (() -> Void)?
    let onDismiss: (() -> Void)?

    @EnvironmentObject var audioService: AudioService
    @Namespace private var glassNamespace

    var body: some View {
        ZStack {
            // Background
            Color(hex: "0A0A12")
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Top bar with glass controls
                topBar
                    .padding(.horizontal, 20)
                    .padding(.top, 16)

                // Scrollable content (plain text, no glass)
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Recording info
                        recordingInfo

                        // AI Summary (if available)
                        if let summary = recording.aiSummary {
                            summarySection(summary)
                        }

                        // Transcript
                        transcriptSection
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 24)
                    .padding(.bottom, 120) // Space for bottom bar
                }

                Spacer(minLength: 0)
            }

            // Bottom action bar (glass)
            VStack {
                Spacer()
                bottomActionBar
                    .padding(.horizontal, 20)
                    .padding(.bottom, 32)
            }
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        GlassEffectContainer(spacing: 12) {
            HStack {
                // Done/Back button
                if let onDismiss {
                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.8))
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.glass)
                    .glassEffectID("dismiss", in: glassNamespace)
                }

                Spacer()

                // Duration badge
                Text(recording.durationFormatted)
                    .font(.monoMedium)
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .glassEffect()
                    .glassEffectID("duration", in: glassNamespace)
            }
        }
    }

    // MARK: - Recording Info

    private var recordingInfo: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(recording.createdAt.formatted(date: .abbreviated, time: .shortened))
                .font(.headlineSecondary)
                .foregroundStyle(.white.opacity(0.9))

            HStack(spacing: 8) {
                statusIndicator
                Text(statusText)
                    .font(.captionSecondary)
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
    }

    private var statusIndicator: some View {
        Circle()
            .fill(statusColor)
            .frame(width: 8, height: 8)
    }

    private var statusColor: Color {
        switch recording.transcriptionStatus {
        case .pending, .inProgress:
            return .yellow
        case .completed:
            return .green
        case .failed:
            return .red
        }
    }

    private var statusText: String {
        switch recording.transcriptionStatus {
        case .pending:
            return "Waiting to transcribe..."
        case .inProgress:
            return "Transcribing..."
        case .completed:
            return "Transcribed"
        case .failed:
            return "Transcription failed"
        }
    }

    // MARK: - Summary Section

    private func summarySection(_ summary: String) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section header
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 14, weight: .medium))
                Text("Summary")
                    .font(.captionPrimary)
            }
            .foregroundStyle(.white.opacity(0.5))

            // Summary text (plain, no glass)
            Text(summary)
                .font(.bodyPrimary)
                .foregroundStyle(.white.opacity(0.9))
                .lineSpacing(6)

            // Key points (if available)
            if let points = recording.aiKeyPoints, !points.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(points, id: \.self) { point in
                        HStack(alignment: .top, spacing: 12) {
                            Circle()
                                .fill(.white.opacity(0.4))
                                .frame(width: 6, height: 6)
                                .padding(.top, 7)
                            Text(point)
                                .font(.bodySecondary)
                                .foregroundStyle(.white.opacity(0.75))
                        }
                    }
                }
                .padding(.top, 4)
            }
        }
    }

    // MARK: - Transcript Section

    private var transcriptSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Divider
            Rectangle()
                .fill(.white.opacity(0.1))
                .frame(height: 1)
                .padding(.vertical, 8)

            // Section header
            HStack(spacing: 8) {
                Image(systemName: "text.quote")
                    .font(.system(size: 14, weight: .medium))
                Text("Transcript")
                    .font(.captionPrimary)
            }
            .foregroundStyle(.white.opacity(0.5))

            // Transcript text (plain, no glass)
            if let transcript = recording.transcript, !transcript.isEmpty {
                Text(transcript)
                    .font(.bodyPrimary)
                    .foregroundStyle(.white.opacity(0.9))
                    .lineSpacing(8)
            } else {
                switch recording.transcriptionStatus {
                case .pending, .inProgress:
                    HStack(spacing: 12) {
                        ProgressView()
                            .tint(.white.opacity(0.6))
                        Text("Transcribing...")
                            .font(.bodySecondary)
                            .foregroundStyle(.white.opacity(0.5))
                    }
                case .failed:
                    Text("Transcription failed")
                        .font(.bodySecondary)
                        .foregroundStyle(.red.opacity(0.7))
                case .completed:
                    Text("No transcript available")
                        .font(.bodySecondary)
                        .foregroundStyle(.white.opacity(0.5))
                        .italic()
                }
            }
        }
    }

    // MARK: - Bottom Action Bar

    private var bottomActionBar: some View {
        GlassEffectContainer(spacing: 12) {
            HStack(spacing: 12) {
                // Play/Pause button
                Button(action: togglePlayback) {
                    HStack(spacing: 8) {
                        Image(systemName: audioService.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 16, weight: .semibold))
                        Text(audioService.isPlaying ? "Pause" : "Play")
                            .font(.buttonLabel)
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                }
                .buttonStyle(.glass)
                .glassEffectID("playBtn", in: glassNamespace)

                // Resume button (if available)
                if let onResume {
                    Button(action: onResume) {
                        HStack(spacing: 8) {
                            Image(systemName: "mic.fill")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Resume")
                                .font(.buttonLabel)
                        }
                        .foregroundStyle(.white.opacity(0.85))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                    }
                    .buttonStyle(.glass)
                    .glassEffectID("resumeBtn", in: glassNamespace)
                }

                // New recording button
                Button(action: onNewRecording) {
                    Image(systemName: "waveform.badge.plus")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.8))
                        .frame(width: 52, height: 52)
                }
                .buttonStyle(.glass)
                .glassEffectID("newBtn", in: glassNamespace)
            }
        }
    }

    // MARK: - Actions

    private func togglePlayback() {
        if audioService.isPlaying {
            audioService.pause()
        } else {
            do {
                try audioService.play(url: recording.audioURL)
            } catch {
                print("Failed to play recording: \(error)")
            }
        }
    }
}

#Preview {
    CompletedRecordingView(
        recording: Recording(
            audioFileName: "test.m4a",
            transcriptionStatus: .completed
        ),
        onNewRecording: {},
        onResume: {},
        onDismiss: {}
    )
    .environmentObject(AudioService())
}
