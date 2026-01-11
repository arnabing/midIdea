import SwiftUI

struct LibraryView: View {
    @EnvironmentObject var recordingStore: RecordingStore
    @EnvironmentObject var audioService: AudioService
    @Environment(\.dismiss) private var dismiss

    @State private var selectedRecording: Recording?
    @State private var showingDetail = false

    var body: some View {
        NavigationStack {
            Group {
                if recordingStore.recordings.isEmpty {
                    EmptyLibraryView()
                } else {
                    recordingsList
                }
            }
            .navigationTitle("Recordings")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .sheet(item: $selectedRecording) { recording in
            RecordingDetailView(recording: recording)
        }
    }

    private var recordingsList: some View {
        List {
            ForEach(recordingStore.recordings) { recording in
                RecordingRowView(
                    recording: recording,
                    isPlaying: audioService.isPlaying && recordingStore.currentRecording?.id == recording.id,
                    onTap: {
                        playRecording(recording)
                    },
                    onDetailTap: {
                        selectedRecording = recording
                    }
                )
            }
            .onDelete(perform: deleteRecordings)
        }
        .listStyle(.insetGrouped)
    }

    private func playRecording(_ recording: Recording) {
        if audioService.isPlaying && recordingStore.currentRecording?.id == recording.id {
            audioService.pause()
        } else {
            do {
                recordingStore.currentRecording = recording
                try audioService.play(url: recording.audioURL)
            } catch {
                print("Failed to play recording: \(error)")
            }
        }
    }

    private func deleteRecordings(at offsets: IndexSet) {
        recordingStore.deleteRecording(at: offsets)
    }
}

struct EmptyLibraryView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "waveform")
                .font(.system(size: 60))
                .foregroundColor(.secondary)

            Text("No Recordings Yet")
                .font(.title2)
                .fontWeight(.medium)

            Text("Hold the record button to capture your first voice note")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }
}

struct RecordingRowView: View {
    let recording: Recording
    let isPlaying: Bool
    let onTap: () -> Void
    let onDetailTap: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Cassette icon
            CassetteTapeIcon(isPlaying: isPlaying)
                .frame(width: 50, height: 32)

            // Recording info
            VStack(alignment: .leading, spacing: 4) {
                Text(recording.displayTitle)
                    .font(.headline)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    // Duration
                    Label(recording.durationFormatted, systemImage: "clock")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    // Transcription status
                    TranscriptionStatusBadge(status: recording.transcriptionStatus)
                }

                // Transcript preview
                if let transcript = recording.transcript, !transcript.isEmpty {
                    Text(transcript)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            // Detail button
            Button(action: onDetailTap) {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }
}

struct CassetteTapeIcon: View {
    let isPlaying: Bool

    @State private var rotation: Double = 0

    var body: some View {
        ZStack {
            // Tape body
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.gray.opacity(0.3))

            // Reels
            HStack(spacing: 8) {
                Circle()
                    .fill(Color.brown.opacity(0.6))
                    .frame(width: 12, height: 12)
                    .rotationEffect(.degrees(rotation))

                Circle()
                    .fill(Color.brown.opacity(0.6))
                    .frame(width: 12, height: 12)
                    .rotationEffect(.degrees(rotation))
            }
        }
        .onChange(of: isPlaying) { _, playing in
            if playing {
                withAnimation(.linear(duration: 1).repeatForever(autoreverses: false)) {
                    rotation = 360
                }
            } else {
                rotation = 0
            }
        }
    }
}

struct TranscriptionStatusBadge: View {
    let status: TranscriptionStatus

    var body: some View {
        HStack(spacing: 2) {
            statusIcon
            Text(statusText)
        }
        .font(.caption2)
        .foregroundColor(statusColor)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(
            Capsule()
                .fill(statusColor.opacity(0.15))
        )
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch status {
        case .pending:
            Image(systemName: "clock")
        case .inProgress:
            Image(systemName: "arrow.triangle.2.circlepath")
        case .completed:
            Image(systemName: "checkmark")
        case .failed:
            Image(systemName: "exclamationmark.triangle")
        }
    }

    private var statusText: String {
        switch status {
        case .pending: return "Pending"
        case .inProgress: return "Transcribing"
        case .completed: return "Done"
        case .failed: return "Failed"
        }
    }

    private var statusColor: Color {
        switch status {
        case .pending: return .orange
        case .inProgress: return .blue
        case .completed: return .green
        case .failed: return .red
        }
    }
}

#Preview {
    LibraryView()
        .environmentObject(RecordingStore())
        .environmentObject(AudioService())
}
