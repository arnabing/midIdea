import SwiftUI

/// A sheet presenting all recordings in a minimal list format.
/// Accessed by swiping up from the main recorder view.
struct MinimalRecordingsList: View {
    @EnvironmentObject var recordingStore: RecordingStore
    @Environment(\.dismiss) private var dismiss

    @State private var selectedRecording: Recording?

    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                Color(hex: "1C1C1E")
                    .ignoresSafeArea()

                if recordingStore.recordings.isEmpty {
                    emptyState
                } else {
                    recordingsList
                }
            }
            .navigationTitle("Recordings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
            .toolbarBackground(Color(hex: "1C1C1E"), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
        .sheet(item: $selectedRecording) { recording in
            CompletedRecordingView(
                recording: recording,
                onNewRecording: {
                    selectedRecording = nil
                    dismiss()
                },
                onResume: nil,
                onDismiss: { selectedRecording = nil }
            )
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "waveform")
                .font(.system(size: 48))
                .foregroundColor(.white.opacity(0.3))

            Text("No Recordings Yet")
                .font(.title3)
                .fontWeight(.medium)
                .foregroundColor(.white.opacity(0.6))

            Text("Press the Action Button to record")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.4))
        }
    }

    // MARK: - Recordings List

    private var recordingsList: some View {
        List {
            ForEach(recordingStore.recordings) { recording in
                RecordingRow(recording: recording)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedRecording = recording
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparatorTint(.white.opacity(0.1))
            }
            .onDelete(perform: deleteRecordings)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    // MARK: - Actions

    private func deleteRecordings(at offsets: IndexSet) {
        for index in offsets {
            let recording = recordingStore.recordings[index]
            recordingStore.deleteRecording(recording)
        }
    }
}

// MARK: - Recording Row

private struct RecordingRow: View {
    let recording: Recording

    var body: some View {
        HStack(spacing: 12) {
            // Status indicator
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 4) {
                // Date and time
                Text(recording.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white.opacity(0.9))

                // Transcript preview or status
                Text(transcriptPreview)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.5))
                    .lineLimit(1)
            }

            Spacer()

            // Duration
            Text(formatDuration(recording.duration))
                .font(.caption)
                .foregroundColor(.white.opacity(0.4))
                .monospacedDigit()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.white.opacity(0.3))
        }
        .padding(.vertical, 8)
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

    private var transcriptPreview: String {
        switch recording.transcriptionStatus {
        case .pending:
            return "Waiting to transcribe..."
        case .inProgress:
            return "Transcribing..."
        case .completed:
            return recording.transcript ?? "No transcript"
        case .failed:
            return "Transcription failed"
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}


#Preview {
    MinimalRecordingsList()
        .environmentObject(RecordingStore())
        .environmentObject(AudioService())
}
