import SwiftUI

struct RecordingDetailView: View {
    let recording: Recording

    @EnvironmentObject var recordingStore: RecordingStore
    @EnvironmentObject var audioService: AudioService
    @Environment(\.dismiss) private var dismiss

    @State private var playbackRate: Float = 1.0
    @State private var showCopiedToast = false
    @State private var isRetranscribing = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header with cassette visual
                    recordingHeader

                    // Playback controls
                    playbackSection

                    // Transcript section
                    transcriptSection
                }
                .padding()
            }
            .navigationTitle("Recording")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        audioService.stop()
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: shareRecording) {
                            Label("Share Audio", systemImage: "square.and.arrow.up")
                        }

                        if recording.transcript != nil {
                            Button(action: shareTranscript) {
                                Label("Share Transcript", systemImage: "doc.text")
                            }
                        }

                        Divider()

                        Button(role: .destructive, action: deleteRecording) {
                            Label("Delete", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .overlay(
                copiedToast
                    .opacity(showCopiedToast ? 1 : 0)
                    .animation(.easeInOut, value: showCopiedToast)
            )
        }
    }

    // MARK: - Recording Header

    private var recordingHeader: some View {
        VStack(spacing: 12) {
            // Mini cassette visualization
            CassetteView(
                isAnimating: audioService.isPlaying,
                isRecording: false
            )
            .frame(height: 100)

            // Date and duration
            VStack(spacing: 4) {
                Text(recording.displayTitle)
                    .font(.headline)

                Text(recording.durationFormatted)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - Playback Section

    private var playbackSection: some View {
        VStack(spacing: 16) {
            // Progress bar
            if audioService.isPlaying || audioService.currentTime > 0 {
                ProgressView(value: audioService.currentTime, total: audioService.duration)
                    .tint(.red)

                HStack {
                    Text(formatTime(audioService.currentTime))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(formatTime(audioService.duration))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // Controls
            HStack(spacing: 24) {
                Button(action: { audioService.skipBackward() }) {
                    Image(systemName: "gobackward.10")
                        .font(.title2)
                }
                .disabled(!audioService.isPlaying)

                Button(action: togglePlayback) {
                    Image(systemName: audioService.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.red)
                }

                Button(action: { audioService.skipForward() }) {
                    Image(systemName: "goforward.10")
                        .font(.title2)
                }
                .disabled(!audioService.isPlaying)
            }

            // Speed control
            PlaybackSpeedView(rate: $playbackRate)
                .onChange(of: playbackRate) { _, newValue in
                    audioService.setPlaybackRate(newValue)
                }
        }
        .padding()
        .glassEffect(.regular, in: .rect(cornerRadius: 16))
    }

    // MARK: - Transcript Section

    private var transcriptSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Transcript")
                    .font(.headline)

                Spacer()

                if recording.transcriptionStatus == .completed {
                    Button(action: copyTranscript) {
                        Label("Copy", systemImage: "doc.on.doc")
                            .font(.subheadline)
                    }
                }

                if recording.transcriptionStatus == .failed || recording.transcriptionStatus == .pending {
                    Button(action: retranscribe) {
                        Label(isRetranscribing ? "Transcribing..." : "Retry", systemImage: "arrow.clockwise")
                            .font(.subheadline)
                    }
                    .disabled(isRetranscribing)
                }
            }

            transcriptContent
        }
        .padding()
        .glassEffect(.regular, in: .rect(cornerRadius: 16))
    }

    @ViewBuilder
    private var transcriptContent: some View {
        switch recording.transcriptionStatus {
        case .pending:
            HStack {
                Image(systemName: "clock")
                Text("Transcription pending...")
            }
            .foregroundColor(.secondary)

        case .inProgress:
            HStack {
                ProgressView()
                    .scaleEffect(0.8)
                Text("Transcribing...")
            }
            .foregroundColor(.secondary)

        case .completed:
            if let transcript = recording.transcript, !transcript.isEmpty {
                Text(transcript)
                    .font(.body)
                    .textSelection(.enabled)
            } else {
                Text("No speech detected")
                    .foregroundColor(.secondary)
                    .italic()
            }

        case .failed:
            HStack {
                Image(systemName: "exclamationmark.triangle")
                Text("Transcription failed. Tap retry to try again.")
            }
            .foregroundColor(.red)
        }
    }

    // MARK: - Toast

    private var copiedToast: some View {
        VStack {
            Spacer()
            Text("Copied to clipboard")
                .font(.subheadline)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .glassEffect(.regular, in: .capsule)
                .padding(.bottom, 40)
        }
    }

    // MARK: - Actions

    private func togglePlayback() {
        if audioService.isPlaying {
            audioService.pause()
        } else {
            do {
                try audioService.play(url: recording.audioURL, rate: playbackRate)
            } catch {
                print("Playback failed: \(error)")
            }
        }
    }

    private func copyTranscript() {
        guard let transcript = recording.transcript else { return }
        UIPasteboard.general.string = transcript
        showCopiedToast = true
        HapticService.shared.playSaveSuccess()

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            showCopiedToast = false
        }
    }

    private func shareRecording() {
        // TODO: Implement share sheet
    }

    private func shareTranscript() {
        // TODO: Implement share sheet
    }

    private func deleteRecording() {
        audioService.stop()
        recordingStore.deleteRecording(recording)
        dismiss()
    }

    private func retranscribe() {
        isRetranscribing = true

        var updatedRecording = recording
        updatedRecording.transcriptionStatus = .inProgress
        recordingStore.updateRecording(updatedRecording)

        Task {
            do {
                let transcript = try await TranscriptionService.shared.transcribe(audioURL: recording.audioURL)
                updatedRecording.transcript = transcript
                updatedRecording.transcriptionStatus = .completed
            } catch {
                updatedRecording.transcriptionStatus = .failed
            }
            recordingStore.updateRecording(updatedRecording)
            isRetranscribing = false
        }
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

#Preview {
    RecordingDetailView(
        recording: Recording(
            audioFileName: "test.m4a",
            transcript: "This is a sample transcript of the recording.",
            transcriptionStatus: .completed
        )
    )
    .environmentObject(RecordingStore())
    .environmentObject(AudioService())
}
