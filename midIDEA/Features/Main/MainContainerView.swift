import SwiftUI

/// Root container view - Recording-first navigation with sidebar drawer
/// Recording screen is always visible, sidebar slides in from left
struct MainContainerView: View {
    @EnvironmentObject var recordingStore: RecordingStore
    @EnvironmentObject var audioService: AudioService

    // Navigation state
    @State private var showSidebar = false
    @State private var navigationPath = NavigationPath()
    @State private var selectedRecordingId: UUID?

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
            .navigationDestination(for: UUID.self) { recordingId in
                TranscriptDetailView(recordingId: recordingId)
            }
        }
        .highPriorityGesture(navigationPath.isEmpty ? edgeSwipeGesture : nil)
        .overlay {
            // Sidebar drawer from left
            SidebarDrawer(
                isPresented: $showSidebar,
                selectedRecordingId: $selectedRecordingId,
                onSelectRecording: { recording in
                    showSidebar = false
                    selectedRecordingId = recording.id
                    navigationPath.append(recording.id)
                },
                onNewRecording: {
                    showSidebar = false
                    selectedRecordingId = nil
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

        Task {
            var recording = Recording(
                duration: audioService.currentTime,
                audioFileName: url.lastPathComponent
            )

            // Pre-generate waveform BEFORE adding recording
            do {
                let samples = try await WaveformGenerator.generate(
                    from: url,
                    sampleCount: 200
                )
                recording.waveformSamples = samples  // In-memory cache (instant)

                // Fire-and-forget disk write (don't block navigation)
                Task.detached(priority: .utility) {
                    try? recording.saveWaveform(samples)
                }
            } catch {
                print("Waveform pre-generation failed: \(error)")
                // Continue without waveform - will generate on-demand
            }

            // Add to store and navigate immediately
            recordingStore.addRecording(recording)
            currentRecordingURL = nil
            navigationPath.append(recording.id)

            // Start transcription
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
    @State private var visualStyle: VisualizerStyle = .metalOrb
    @State private var showStyleName = false

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
            VisualizerContainer(
                audioLevel: audioService.peakLevel,
                frequencyBands: audioService.frequencyBands,
                onsetBands: audioService.onsetBands,
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
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(.black.opacity(0.8))
                    }
                    .frame(width: 48, height: 48)
                    .glassEffect(.regular.interactive(), in: .circle)

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
        .overlay(alignment: .top) {
            if showStyleName {
                Text(visualStyle.rawValue)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial, in: Capsule())
                    .transition(.opacity.combined(with: .scale(scale: 0.8)))
                    .padding(.top, 80)
            }
        }
        .simultaneousGesture(
            TapGesture(count: 3)
                .onEnded { _ in
                    // Cycle through all visual styles
                    let allStyles = VisualizerStyle.allCases
                    let currentIndex = allStyles.firstIndex(of: visualStyle) ?? 0
                    let nextIndex = (currentIndex + 1) % allStyles.count
                    withAnimation(.easeInOut(duration: 0.3)) {
                        visualStyle = allStyles[nextIndex]
                        showStyleName = true
                    }
                    // Auto-hide after 1.5s
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        withAnimation(.easeOut(duration: 0.3)) {
                            showStyleName = false
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

// MARK: - Sidebar Drawer (Clean Style)

/// Sidebar that slides in from the left - clean minimal design like Claude app
struct SidebarDrawer: View {
    @EnvironmentObject var recordingStore: RecordingStore
    @Binding var isPresented: Bool
    @Binding var selectedRecordingId: UUID?
    let onSelectRecording: (Recording) -> Void
    let onNewRecording: () -> Void

    @State private var dragOffset: CGFloat = 0
    @State private var searchText = ""

    private let sidebarWidth: CGFloat = 300

    private var filteredRecordings: [Recording] {
        if searchText.isEmpty {
            return recordingStore.recordings
        }
        return recordingStore.recordings.filter { recording in
            recording.displayTitle.localizedCaseInsensitiveContains(searchText)
        }
    }

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
                        // Search bar + New button row
                        HStack(spacing: 12) {
                            // Search field
                            HStack(spacing: 8) {
                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: 15))
                                    .foregroundStyle(.secondary)
                                TextField("Search", text: $searchText)
                                    .font(.body)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))

                            // New recording button
                            Button(action: onNewRecording) {
                                Image(systemName: "square.and.pencil")
                                    .font(.system(size: 18))
                                    .foregroundStyle(.primary)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 60)
                        .padding(.bottom, 16)

                        // Recordings list
                        if filteredRecordings.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: searchText.isEmpty ? "waveform" : "magnifyingglass")
                                    .font(.system(size: 32))
                                    .foregroundStyle(.tertiary)
                                Text(searchText.isEmpty ? "No recordings yet" : "No results")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 40)
                        } else {
                            ScrollView {
                                LazyVStack(spacing: 0) {
                                    ForEach(filteredRecordings) { recording in
                                        SidebarRow(
                                            recording: recording,
                                            isSelected: selectedRecordingId == recording.id,
                                            onSelect: { onSelectRecording(recording) },
                                            onDelete: { recordingStore.deleteRecording(recording) }
                                        )
                                    }
                                }
                                .padding(.bottom, 20)
                            }
                        }

                        Spacer()
                    }
                    .frame(width: sidebarWidth)
                    .background(Color(uiColor: .systemBackground))

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

// MARK: - Sidebar Row (Simple Text Style)

private struct SidebarRow: View {
    let recording: Recording
    let isSelected: Bool
    let onSelect: () -> Void
    let onDelete: () -> Void

    var body: some View {
        Button(action: onSelect) {
            Text(recording.displayTitle)
                .font(.body)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(isSelected ? Color.primary.opacity(0.1) : Color.clear)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                shareRecording()
            } label: {
                Label("Share", systemImage: "square.and.arrow.up")
            }

            Divider()

            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private func shareRecording() {
        let activityVC = UIActivityViewController(
            activityItems: [recording.audioURL],
            applicationActivities: nil
        )
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
    }
}

#Preview {
    MainContainerView()
        .environmentObject(RecordingStore())
        .environmentObject(AudioService())
}
