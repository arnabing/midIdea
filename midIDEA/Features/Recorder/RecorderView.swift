import SwiftUI

struct RecorderView: View {
    @EnvironmentObject var audioService: AudioService
    @EnvironmentObject var recordingStore: RecordingStore

    @State private var recordingState: RecordingState = .idle
    @State private var countdownValue: Int = 3
    @State private var showTranscript = false
    @State private var currentRecordingURL: URL?
    @State private var playbackRate: Float = 1.0

    var body: some View {
        VStack(spacing: 20) {
            // Brand name
            Text("midIDEA")
                .font(.custom("Marker Felt", size: 32))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.primary, .primary.opacity(0.7)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .shadow(color: .black.opacity(0.3), radius: 1, x: 1, y: 1)

            // Cassette window
            CassetteView(
                isAnimating: audioService.isRecording || audioService.isPlaying,
                isRecording: audioService.isRecording
            )
            .frame(height: 140)

            // VU Meter
            VUMeterView(level: audioService.audioLevel)
                .frame(height: 30)
                .padding(.horizontal, 40)

            // Time display
            TimeDisplayView(
                currentTime: audioService.currentTime,
                duration: audioService.isPlaying ? audioService.duration : nil,
                isRecording: audioService.isRecording
            )

            // Transport controls
            TransportControlsView(
                isPlaying: audioService.isPlaying,
                isRecording: audioService.isRecording,
                onRewind: { audioService.skipBackward() },
                onFastForward: { audioService.skipForward() },
                onPlay: handlePlay,
                onStop: handleStop
            )

            // Hold-to-record button
            HoldToRecordButton(
                recordingState: $recordingState,
                countdownValue: $countdownValue,
                onRecordingStart: startRecording,
                onRecordingEnd: endRecording,
                onRecordingCancel: cancelRecording
            )
            .padding(.top, 10)

            // Playback speed slider (when playing)
            if audioService.isPlaying {
                PlaybackSpeedView(rate: $playbackRate)
                    .onChange(of: playbackRate) { _, newValue in
                        audioService.setPlaybackRate(newValue)
                    }
            }
        }
        .padding()
    }

    // MARK: - Actions

    private func startRecording() {
        do {
            currentRecordingURL = try audioService.startRecording()
        } catch {
            print("Failed to start recording: \(error)")
        }
    }

    private func endRecording() {
        guard let result = audioService.stopRecording() else { return }

        let recording = Recording(
            audioFileName: result.url.lastPathComponent,
            transcriptionStatus: .pending
        )

        var mutableRecording = recording
        mutableRecording.duration = result.duration

        recordingStore.addRecording(mutableRecording)

        // Start transcription
        Task {
            await transcribeRecording(mutableRecording)
        }
    }

    private func cancelRecording() {
        audioService.cancelRecording()
        currentRecordingURL = nil
    }

    private func handlePlay() {
        if audioService.isPlaying {
            audioService.pause()
        } else if let recording = recordingStore.recordings.first {
            do {
                try audioService.play(url: recording.audioURL, rate: playbackRate)
            } catch {
                print("Failed to play: \(error)")
            }
        }
    }

    private func handleStop() {
        if audioService.isRecording {
            endRecording()
            recordingState = .idle
        } else if audioService.isPlaying {
            audioService.stop()
        }
    }

    private func transcribeRecording(_ recording: Recording) async {
        var updatedRecording = recording
        updatedRecording.transcriptionStatus = .inProgress
        recordingStore.updateRecording(updatedRecording)

        do {
            let transcript = try await TranscriptionService.shared.transcribe(audioURL: recording.audioURL)
            updatedRecording.transcript = transcript
            updatedRecording.transcriptionStatus = .completed
        } catch {
            print("Transcription failed: \(error)")
            updatedRecording.transcriptionStatus = .failed
        }

        recordingStore.updateRecording(updatedRecording)
    }
}

enum RecordingState {
    case idle
    case recording
    case countdown
}

#Preview {
    RecorderView()
        .environmentObject(AudioService())
        .environmentObject(RecordingStore())
}
