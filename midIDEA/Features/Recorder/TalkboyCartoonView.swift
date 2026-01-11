import SwiftUI
import AVFoundation

struct TalkboyCartoonView: View {
    @EnvironmentObject var audioService: AudioService
    @EnvironmentObject var recordingStore: RecordingStore

    @State private var showingLibrary = false
    @State private var volume: Float = 1.0
    @State private var playbackSpeed: Float = 1.0
    @State private var showPermissionAlert = false
    @State private var currentRecordingURL: URL?
    
    // Sample Playback State
    @State private var playingSample = false
    @State private var samplePlayer: AVAudioPlayer?

    // Image/SVG Dimensions
    private let svgWidth: CGFloat = 400
    private let svgHeight: CGFloat = 300

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background - "iOS 26 Liquid Glass" Effect
                // Simulating a futuristic, ultra-smooth blur with multiple layers
                ZStack {
                    // Deep base layer for depth
                    Color.black.opacity(0.8).ignoresSafeArea()
                    
                    // Vibrant, abstract gradient blobs for the "liquid" feel
                    GeometryReader { geo in
                        ZStack {
                            Circle()
                                .fill(Color.blue.opacity(0.3))
                                .frame(width: 300, height: 300)
                                .blur(radius: 60)
                                .position(x: geo.size.width * 0.2, y: geo.size.height * 0.3)
                            
                            Circle()
                                .fill(Color.purple.opacity(0.3))
                                .frame(width: 400, height: 400)
                                .blur(radius: 80)
                                .position(x: geo.size.width * 0.8, y: geo.size.height * 0.7)
                            
                            Circle()
                                .fill(Color.cyan.opacity(0.2))
                                .frame(width: 250, height: 250)
                                .blur(radius: 50)
                                .position(x: geo.size.width * 0.5, y: geo.size.height * 0.5)
                        }
                    }
                    .ignoresSafeArea()
                    
                    // The "Glass" Surface
                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .ignoresSafeArea()
                }
                
                // Scale to fit the screen while maintaining aspect ratio
                // "Learn from dimensions" -> Use standard aspect fit logic
                // User reported 1.75 was "small", but logic suggests it should be large. 
                // Stick to 1.75 for now or adjust if we find the image has padding.
                let ratio = min(geometry.size.width / svgWidth, geometry.size.height / svgHeight)
                let scale = ratio * 1.75
                
                ZStack {
                    // 1. Image Background (Replaces Vector Layers)
                    Image("TalkboyCartoonBackground")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: svgWidth, height: svgHeight)
                    
                    // 2. Interactive Elements Aligned to Image Coordinates
                    // Using previous SVG coordinates as a baseline for the screenshot
                    
                    // Cassette Reel Removed per request
                    
                    // Invisible Touch Targets for Buttons (Top Bezel)
                    Group {
                        // Stop (Far Left)
                        Button(action: handleStop) { 
                             Color.white.opacity(0.01) // Nearly invisible but hit-testable
                                .contentShape(Rectangle()) 
                        }
                            .frame(width: 30, height: 30) // Slightly larger touch target
                            .position(x: 182, y: 104)
                        
                        // Rewind
                        Button(action: { audioService.skipBackward() }) { 
                             Color.white.opacity(0.01)
                                .contentShape(Rectangle())
                        }
                            .frame(width: 30, height: 30)
                            .position(x: 200, y: 104)
                        
                        // Play (Long press for Sample?)
                        Button(action: handlePlay) { 
                             Color.white.opacity(0.01)
                                .contentShape(Rectangle())
                        }
                            .simultaneousGesture(LongPressGesture(minimumDuration: 1.0).onEnded { _ in
                                playRandomSample()
                            })
                            .frame(width: 30, height: 30)
                            .position(x: 225, y: 104)
                        
                        // Fast Forward
                        Button(action: { audioService.skipForward() }) { 
                             Color.white.opacity(0.01)
                                .contentShape(Rectangle())
                        }
                            .frame(width: 30, height: 30)
                            .position(x: 253, y: 104)
                        
                        // Record (Red Button - Far Right)
                        Button(action: handleRecord) { 
                             Color.white.opacity(0.01)
                                .contentShape(Rectangle())
                        }
                            .frame(width: 30, height: 30)
                            .position(x: 275, y: 104)
                    }
                    
                    // Sliders (Bottom)
                    CartoonSliderTouchArea(value: $volume, range: 0...1)
                        .frame(width: 40, height: 20)
                        .position(x: 165, y: 220)
                    
                    CartoonSliderTouchArea(value: $playbackSpeed, range: 0.5...2.0)
                        .frame(width: 40, height: 20)
                        .position(x: 235, y: 220)
                    
                }
                .frame(width: svgWidth, height: svgHeight)
                .scaleEffect(scale)
                .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
            }
        }
        .ignoresSafeArea()
        .onChange(of: volume) { _, newValue in audioService.setVolume(newValue) }
        .onChange(of: playbackSpeed) { _, newValue in audioService.setPlaybackRate(newValue) }
        // Alerts and Sheets
        .alert("Microphone Access Required", isPresented: $showPermissionAlert) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Please enable microphone access in Settings to record voice notes.")
        }
        .sheet(isPresented: $showingLibrary) {
            LibraryView()
        }
        // Intent Listeners
        .onReceive(NotificationCenter.default.publisher(for: .startRecordingFromIntent)) { _ in handleRecord() }
        .onReceive(NotificationCenter.default.publisher(for: .toggleRecordingFromIntent)) { _ in
            if audioService.isRecording { handleStop() } else { handleRecord() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .stopRecordingFromIntent)) { _ in handleStop() }
    }
    
    // MARK: - Actions
    private func handleRecord() {
        Task {
            let granted = await audioService.requestMicrophonePermission()
            if granted {
                do { currentRecordingURL = try audioService.startRecording() }
                catch { print("Failed to start recording: \(error)") }
            } else { showPermissionAlert = true }
        }
    }

    private func handleStop() {
        if audioService.isRecording {
            guard let result = audioService.stopRecording() else { return }
            let recording = Recording(audioFileName: result.url.lastPathComponent, transcriptionStatus: .pending)
            var mutableRecording = recording
            mutableRecording.duration = result.duration
            recordingStore.addRecording(mutableRecording)
            
            // Auto-transcribe
            Task { await transcribeRecording(mutableRecording) }
            
            // Wave-like feature: Immediately show the library/content after capturing
            showingLibrary = true
        } else if audioService.isPlaying {
            audioService.stop()
        } else {
            // If idle and Stop is pressed -> Eject/Open Library
            showingLibrary = true
        }
    }

    private func handlePlay() {
        if audioService.isPlaying { audioService.pause() }
        else if let recording = recordingStore.recordings.first {
            do { try audioService.play(url: recording.audioURL, rate: playbackSpeed) }
            catch { print("Failed to play: \(error)") }
        }
    }

    private func transcribeRecording(_ recording: Recording) async {
        var updated = recording
        updated.transcriptionStatus = .inProgress
        recordingStore.updateRecording(updated)
        do {
            let transcript = try await TranscriptionService.shared.transcribe(audioURL: recording.audioURL)
            updated.transcript = transcript
            updated.transcriptionStatus = .completed
        } catch {
            updated.transcriptionStatus = .failed
        }
        recordingStore.updateRecording(updated)
    }
    
    private func playRandomSample() {
        // Placeholder for Home Alone 2 samples
        // In a real app, these would be in the bundle
        print("Playing Home Alone sample...")
        // Logic: Pick random file from bundle, play using AVAudioPlayer
    }
}

// Helper for invisible slider touch
struct CartoonSliderTouchArea: View {
    @Binding var value: Float
    let range: ClosedRange<Float>
    
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            Color.clear
                .contentShape(Rectangle())
                .gesture(
                    DragGesture().onChanged { g in
                        let clampedX = min(max(g.location.x, 0), w)
                        let t = Float(clampedX / w)
                        let rangeSpan = range.upperBound - range.lowerBound
                        value = range.lowerBound + t * rangeSpan
                    }
                )
            
            // Optional: Draw a small thumb indicator
            let rangeSpan = range.upperBound - range.lowerBound
            let normalized = CGFloat((value - range.lowerBound) / rangeSpan)
            
            Rectangle()
                .fill(Color(hex: "bac2c7"))
                .frame(width: 8, height: 12)
                .position(x: normalized * w, y: geo.size.height / 2)
                .shadow(radius: 1)
                .allowsHitTesting(false)
        }
    }
}

// Preview to verify layout
#Preview {
    TalkboyCartoonView()
        .environmentObject(AudioService())
        .environmentObject(RecordingStore())
}
