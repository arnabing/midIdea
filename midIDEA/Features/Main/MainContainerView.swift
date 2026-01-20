import SwiftUI

/// Root container view using iOS 26 NavigationSplitView with Liquid Glass sidebar
struct MainContainerView: View {
    @EnvironmentObject var recordingStore: RecordingStore
    @EnvironmentObject var audioService: AudioService

    // Navigation state
    @State private var selectedRecording: Recording?
    @State private var columnVisibility: NavigationSplitViewVisibility = .automatic

    // Recording state
    @State private var currentRecordingURL: URL?
    @State private var showRecordingOverlay = true  // Start on recording screen

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            // Sidebar - automatically gets Liquid Glass in iOS 26
            SidebarContent(
                selectedRecording: $selectedRecording,
                onNewRecording: startNewRecording
            )
            .navigationTitle("midIDEA")
        } detail: {
            // Detail content (transcript or empty state - NOT recording)
            if let recording = selectedRecording {
                TranscriptDetailView(recording: recording)
            } else {
                emptyStateView
            }
        }
        .onChange(of: audioService.isRecording) { oldValue, newValue in
            // Handle recording completion (don't sync showRecordingOverlay - we control it manually)
            if oldValue && !newValue && currentRecordingURL != nil {
                // Recording stopped - dismiss overlay and handle completion
                showRecordingOverlay = false
                handleRecordingComplete()
            }
        }
        // Full-screen recording overlay - iOS 26 Camera style
        .fullScreenCover(isPresented: $showRecordingOverlay) {
            RecordingOverlayView(
                onStop: stopRecording,
                onDismiss: { showRecordingOverlay = false },
                onStartRecording: actuallyStartRecording
            )
            .environmentObject(audioService)
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "waveform")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)

            Text("Select a recording")
                .font(.title2)
                .fontWeight(.medium)
                .foregroundStyle(.primary)

            Text("Choose a recording from the sidebar")
                .font(.body)
                .foregroundStyle(.secondary)

            Spacer()
        }
    }

    // MARK: - Actions

    private func startNewRecording() {
        // Just show the overlay - permission requested when user taps record
        showRecordingOverlay = true
    }

    private func actuallyStartRecording() {
        // Called when user taps the record button in the overlay
        Task {
            // Request microphone permission
            let granted = await audioService.requestMicrophonePermission()
            guard granted else {
                print("Microphone permission denied")
                return
            }

            // Setup audio session and start recording
            audioService.setupAudioSession()

            do {
                currentRecordingURL = try audioService.startRecording()
            } catch {
                print("Failed to start recording: \(error)")
                await MainActor.run {
                    showRecordingOverlay = false
                }
            }
        }
    }

    private func stopRecording() {
        _ = audioService.stopRecording()
    }

    private func handleRecordingComplete() {
        guard let url = currentRecordingURL else { return }

        // Create and save recording
        let recording = Recording(
            duration: audioService.currentTime,
            audioFileName: url.lastPathComponent
        )
        recordingStore.addRecording(recording)

        // Auto-select the new recording
        selectedRecording = recording

        // Reset
        currentRecordingURL = nil

        // Start transcription
        Task {
            await transcribe(recording)
        }
    }

    private func transcribe(_ recording: Recording) async {
        var updated = recording
        updated.transcriptionStatus = .inProgress
        recordingStore.updateRecording(updated)

        do {
            let transcript = try await TranscriptionService.shared.transcribe(audioURL: recording.audioURL)
            updated.transcript = transcript
            updated.transcriptionStatus = .completed
            recordingStore.updateRecording(updated)

            // Update selected recording after transcription
            if selectedRecording?.id == updated.id {
                selectedRecording = updated
            }

            // Generate AI summary with Apple Intelligence
            if !transcript.isEmpty {
                await generateAISummary(for: &updated)
            }
        } catch {
            updated.transcriptionStatus = .failed
            print("Transcription failed: \(error)")
            recordingStore.updateRecording(updated)

            if selectedRecording?.id == updated.id {
                selectedRecording = updated
            }
        }
    }

    private func generateAISummary(for recording: inout Recording) async {
        guard let transcript = recording.transcript, !transcript.isEmpty else { return }

        do {
            let insights = try await AIService.shared.generateInsights(transcript)
            recording.aiSummary = insights.summary
            recording.aiKeyPoints = insights.keyPoints
            recordingStore.updateRecording(recording)

            // Update selected recording if it's the same one
            if selectedRecording?.id == recording.id {
                selectedRecording = recording
            }
        } catch {
            print("AI summary generation failed: \(error)")
            // Silent failure - transcript is still available
        }
    }
}

// MARK: - Sidebar Content

/// Sidebar content for NavigationSplitView - iOS 26 Liquid Glass applied automatically
struct SidebarContent: View {
    @EnvironmentObject var recordingStore: RecordingStore
    @Binding var selectedRecording: Recording?
    let onNewRecording: () -> Void

    var body: some View {
        List(selection: $selectedRecording) {
            // New Recording button
            Section {
                Button(action: onNewRecording) {
                    Label("New Recording", systemImage: "plus.circle.fill")
                        .foregroundStyle(.red)
                }
            }

            // Recordings list
            Section("Recordings") {
                ForEach(recordingStore.recordings) { recording in
                    SidebarRowView(recording: recording)
                        .tag(recording)
                }
                .onDelete(perform: deleteRecordings)
            }
        }
        .listStyle(.sidebar)
    }

    private func deleteRecordings(at offsets: IndexSet) {
        for index in offsets {
            let recording = recordingStore.recordings[index]

            // Clear selection if deleting selected recording
            if selectedRecording?.id == recording.id {
                selectedRecording = recordingStore.recordings.first { $0.id != recording.id }
            }

            recordingStore.deleteRecording(recording)
        }
    }
}

// MARK: - Sidebar Recording Row

/// Row view for sidebar recording list
struct SidebarRowView: View {
    let recording: Recording

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(recording.displayTitle)
                .font(.body)
                .lineLimit(1)

            HStack(spacing: 8) {
                Text(recording.formattedDuration)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if recording.transcriptionStatus == .inProgress {
                    ProgressView()
                        .scaleEffect(0.6)
                } else if recording.transcriptionStatus == .failed {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Recording Overlay View (iOS 26 Camera Style)

// Note: PulsingModifier is defined in TimeDisplayView.swift

/// Full-screen recording overlay with iOS 26 Camera app style
/// - Ready state: Red circle button, "Tap to start" hint, close button
/// - Recording state: Red square button (morphed), timer pill with pulsing dot
struct RecordingOverlayView: View {
    @EnvironmentObject var audioService: AudioService
    @Namespace private var buttonNamespace

    let onStop: () -> Void
    let onDismiss: () -> Void
    let onStartRecording: () -> Void

    var body: some View {
        ZStack {
            // Full-screen visualizer (idle when not recording)
            LiquidAudioVisualizer(
                audioLevel: audioService.audioLevel,
                isRecording: audioService.isRecording,
                isIdle: !audioService.isRecording
            )

            // Controls overlay
            VStack(spacing: 0) {
                // Top bar: Close button (only when NOT recording)
                HStack {
                    if !audioService.isRecording {
                        Button(action: onDismiss) {
                            Image(systemName: "xmark")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 40, height: 40)
                        }
                        .buttonStyle(.glass)
                    }
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 60)

                // Status pill
                statusPill
                    .padding(.top, 40)

                Spacer()

                // Record/Stop button
                recordButton
                    .padding(.bottom, 80)
            }
        }
    }

    // MARK: - Status Pill

    @ViewBuilder
    private var statusPill: some View {
        if audioService.isRecording {
            // Recording: Red pill with pulsing dot + REC + time
            HStack(spacing: 12) {
                // Pulsing red dot
                Circle()
                    .fill(Color.red)
                    .frame(width: 12, height: 12)
                    .modifier(PulsingModifier())

                Text("REC")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.red)

                Text(formatTime(audioService.currentTime))
                    .font(.system(size: 18, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .glassEffect()
        } else {
            // Ready: Hint text
            Text("Tap to start recording")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
                .glassEffect()
        }
    }

    // MARK: - Record/Stop Button (iOS 26 Liquid Glass)

    private var recordButton: some View {
        Button(action: toggleRecording) {
            ZStack {
                // Inner shape - morphs circle → square
                if audioService.isRecording {
                    // STOP: Red rounded square
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.red)
                        .frame(width: 28, height: 28)
                } else {
                    // RECORD: Red circle
                    Circle()
                        .fill(Color.red)
                        .frame(width: 52, height: 52)
                }
            }
            .frame(width: 72, height: 72)
        }
        .buttonStyle(.glass)
        .contentShape(.circle)
        .glassEffectID("recordButton", in: buttonNamespace)
        .sensoryFeedback(.impact(flexibility: .soft), trigger: audioService.isRecording)
    }

    // MARK: - Actions

    private func toggleRecording() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            if audioService.isRecording {
                onStop()
            } else {
                onStartRecording()
            }
        }
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

#Preview {
    MainContainerView()
        .environmentObject(RecordingStore())
        .environmentObject(AudioService())
}
