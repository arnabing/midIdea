import SwiftUI

/// Root container view - Recording-first navigation with sidebar drawer
/// Recording screen is always visible, sidebar slides in from left
struct MainContainerView: View {
    @EnvironmentObject var recordingStore: RecordingStore
    @EnvironmentObject var audioService: AudioService

    // Navigation state
    @State private var showSidebar = false
    @State private var navigationPath = NavigationPath()

    // Recording state
    @State private var currentRecordingURL: URL?

    var body: some View {
        NavigationStack(path: $navigationPath) {
            // Root: Recording screen (always the primary view)
            RecordingRootView(
                onOpenSidebar: { showSidebar = true },
                onStop: stopRecording,
                onStartRecording: actuallyStartRecording
            )
            .navigationDestination(for: Recording.self) { recording in
                TranscriptDetailView(recording: recording)
            }
        }
        .highPriorityGesture(navigationPath.isEmpty ? edgeSwipeGesture : nil)
        .overlay {
            // Sidebar drawer from left
            SidebarDrawer(
                isPresented: $showSidebar,
                onSelectRecording: { recording in
                    showSidebar = false
                    navigationPath.append(recording)
                },
                onNewRecording: {
                    showSidebar = false
                    // Already on recording screen, just close sidebar
                }
            )
        }
        .onChange(of: audioService.isRecording) { oldValue, newValue in
            // Handle recording completion
            if oldValue && !newValue && currentRecordingURL != nil {
                handleRecordingComplete()
            }
        }
    }

    // MARK: - Edge Swipe Gesture

    /// Swipe from left edge to open sidebar
    private var edgeSwipeGesture: some Gesture {
        DragGesture(minimumDistance: 20)
            .onEnded { value in
                let startedNearEdge = value.startLocation.x < 40
                let swipedRight = value.translation.width > 50
                let velocityRight = value.predictedEndTranslation.width > 100

                if startedNearEdge && (swipedRight || velocityRight) && !showSidebar {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        showSidebar = true
                    }
                }
            }
    }

    // MARK: - Actions

    private func actuallyStartRecording() {
        Task {
            let granted = await audioService.requestMicrophonePermission()
            guard granted else {
                print("Microphone permission denied")
                return
            }

            audioService.setupAudioSession()

            do {
                currentRecordingURL = try audioService.startRecording()
            } catch {
                print("Failed to start recording: \(error)")
            }
        }
    }

    private func stopRecording() {
        _ = audioService.stopRecording()
    }

    private func handleRecordingComplete() {
        guard let url = currentRecordingURL else { return }

        let recording = Recording(
            duration: audioService.currentTime,
            audioFileName: url.lastPathComponent
        )
        recordingStore.addRecording(recording)
        currentRecordingURL = nil

        // Navigate to the new recording
        navigationPath.append(recording)

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

            if !transcript.isEmpty {
                await generateAISummary(for: &updated)
            }
        } catch {
            updated.transcriptionStatus = .failed
            print("Transcription failed: \(error)")
            recordingStore.updateRecording(updated)
        }
    }

    private func generateAISummary(for recording: inout Recording) async {
        guard let transcript = recording.transcript, !transcript.isEmpty else { return }

        do {
            let insights = try await AIService.shared.generateInsights(transcript)
            recording.aiSummary = insights.summary
            recording.aiKeyPoints = insights.keyPoints
            recordingStore.updateRecording(recording)
        } catch {
            print("AI summary generation failed: \(error)")
        }
    }
}

// MARK: - Recording Root View (Primary Screen)

/// The main recording screen - always visible as root
struct RecordingRootView: View {
    @EnvironmentObject var audioService: AudioService

    let onOpenSidebar: () -> Void
    let onStop: () -> Void
    let onStartRecording: () -> Void

    // Rotating prompts state
    @State private var currentPromptIndex = 0
    @State private var promptOpacity: Double = 1.0
    @State private var promptTimer: Timer?

    // Glass effect namespace
    @Namespace private var buttonNamespace

    // Visual style for experimenting (3-finger tap to cycle)
    @State private var visualStyle: VisualizerStyle = .liquidOcean

    private let prompts = [
        "What do you want to talk about?",
        "Tell me more about it...",
        "What's on your mind?",
        "Share your idea...",
        "Keep going...",
        "What else?",
        "I'm listening...",
        "Go on..."
    ]

    var body: some View {
        ZStack {
            // Full-screen visualizer (disable hit testing so edge swipe works)
            LiquidAudioVisualizer(
                audioLevel: audioService.audioLevel,
                isRecording: audioService.isRecording,
                isIdle: !audioService.isRecording,
                visualStyle: visualStyle
            )
            .allowsHitTesting(false)

            // UI overlay
            VStack(spacing: 0) {
                // Top bar: Sidebar button
                HStack {
                    Button(action: onOpenSidebar) {
                        Image(systemName: "sidebar.left")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.black.opacity(0.8))
                            .frame(width: 44, height: 44)
                            .background(
                                Circle()
                                    .fill(.regularMaterial)
                                    .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
                            )
                    }
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)

                Spacer()

                // Rotating prompt
                Text(prompts[currentPromptIndex])
                    .font(.displayMedium)
                    .foregroundStyle(.black.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .opacity(promptOpacity)
                    .padding(.horizontal, 40)

                Spacer()

                // Record/Stop button with timer overlay
                recordButton
                    .overlay(alignment: .bottom) {
                        // Simple timer (only when recording)
                        if audioService.isRecording {
                            Text(formatTime(audioService.currentTime))
                                .font(.system(size: 14, weight: .medium, design: .monospaced))
                                .foregroundStyle(.black.opacity(0.5))
                                .monospacedDigit()
                                .offset(y: 32)
                        }
                    }
                    .padding(.bottom, 80)
            }
        }
        .navigationBarHidden(true)
        .onAppear { startPromptRotation() }
        .onDisappear { promptTimer?.invalidate() }
        .contentShape(Rectangle())  // Make entire area respond to gestures
        .simultaneousGesture(
            TapGesture(count: 3)
                .onEnded { _ in
                    // Toggle between visual styles: Ocean ↔ Plasma
                    withAnimation(.easeInOut(duration: 0.3)) {
                        switch visualStyle {
                        case .liquidOcean:
                            visualStyle = .plasmaPulse
                        case .plasmaPulse:
                            visualStyle = .liquidOcean
                        }
                    }
                    // Haptic feedback
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                }
        )
    }

    private func startPromptRotation() {
        promptTimer = Timer.scheduledTimer(withTimeInterval: 6.0, repeats: true) { _ in
            withAnimation(.easeOut(duration: 0.5)) {
                promptOpacity = 0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                currentPromptIndex = (currentPromptIndex + 1) % prompts.count
                withAnimation(.easeIn(duration: 0.5)) {
                    promptOpacity = 1
                }
            }
        }
    }

    private var recordButton: some View {
        Button(action: toggleRecording) {
            ZStack {
                if audioService.isRecording {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.red)
                        .frame(width: 26, height: 26)
                } else {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 52, height: 52)
                }
            }
            .frame(width: 72, height: 72)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .circle)
        .sensoryFeedback(.impact(flexibility: .soft), trigger: audioService.isRecording)
    }

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

// MARK: - Sidebar Drawer

/// Sidebar that slides in from the left
struct SidebarDrawer: View {
    @EnvironmentObject var recordingStore: RecordingStore
    @Binding var isPresented: Bool
    let onSelectRecording: (Recording) -> Void
    let onNewRecording: () -> Void

    @State private var dragOffset: CGFloat = 0

    private let sidebarWidth: CGFloat = 300

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Dimmed background
                if isPresented {
                    Color.black
                        .opacity(0.4 * Double(1 - abs(dragOffset) / sidebarWidth))
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                isPresented = false
                            }
                        }
                }

                // Sidebar panel
                HStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 0) {
                        // Header
                        HStack {
                            Text("midIDEA")
                                .font(.title2)
                                .fontWeight(.bold)
                            Spacer()
                            Button(action: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    isPresented = false
                                }
                            }) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 32, height: 32)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 60)
                        .padding(.bottom, 20)

                        // New Recording button
                        Button(action: onNewRecording) {
                            Label("New Recording", systemImage: "plus.circle.fill")
                                .font(.body.weight(.medium))
                                .foregroundStyle(.red)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 12)
                        }

                        Divider()
                            .padding(.vertical, 8)

                        // Recordings list
                        if recordingStore.recordings.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "waveform")
                                    .font(.system(size: 32))
                                    .foregroundStyle(.tertiary)
                                Text("No recordings yet")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 40)
                        } else {
                            ScrollView {
                                LazyVStack(spacing: 4) {
                                    ForEach(recordingStore.recordings) { recording in
                                        SidebarDrawerRow(recording: recording)
                                            .onTapGesture {
                                                onSelectRecording(recording)
                                            }
                                    }
                                }
                                .padding(.horizontal, 12)
                            }
                        }

                        Spacer()
                    }
                    .frame(width: sidebarWidth)
                    .background(.regularMaterial)

                    Spacer()
                }
                .offset(x: isPresented ? dragOffset : -sidebarWidth)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            if value.translation.width < 0 {
                                dragOffset = value.translation.width
                            }
                        }
                        .onEnded { value in
                            if value.translation.width < -100 || value.predictedEndTranslation.width < -200 {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    isPresented = false
                                }
                            }
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                dragOffset = 0
                            }
                        }
                )
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isPresented)
    }
}

// MARK: - Sidebar Drawer Row

private struct SidebarDrawerRow: View {
    let recording: Recording

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Circle()
                .fill(recording.transcriptionStatus == .completed ? Color.green.opacity(0.2) : Color.gray.opacity(0.2))
                .frame(width: 40, height: 40)
                .overlay {
                    if recording.transcriptionStatus == .inProgress {
                        ProgressView()
                            .scaleEffect(0.7)
                    } else {
                        Image(systemName: recording.transcriptionStatus == .completed ? "checkmark" : "waveform")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(recording.transcriptionStatus == .completed ? .green : .secondary)
                    }
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(recording.displayTitle)
                    .font(.body)
                    .lineLimit(1)

                Text(recording.formattedDuration)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.primary.opacity(0.05))
        )
        .contentShape(Rectangle())
    }
}

#Preview {
    MainContainerView()
        .environmentObject(RecordingStore())
        .environmentObject(AudioService())
}
