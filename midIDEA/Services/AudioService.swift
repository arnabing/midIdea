import AVFoundation
import Accelerate
import Combine

// MARK: - Audio File Writer (thread-safe)

/// Wraps AVAudioFile for thread-safe access from the audio render thread.
/// The audio tap callback runs on a real-time thread and can't access @MainActor properties.
private final class AudioFileWriter: @unchecked Sendable {
    private var file: AVAudioFile?
    private let lock = NSLock()

    func open(url: URL, settings: [String: Any]) throws {
        lock.lock()
        defer { lock.unlock() }
        file = try AVAudioFile(forWriting: url, settings: settings)
    }

    func write(_ buffer: AVAudioPCMBuffer) {
        lock.lock()
        defer { lock.unlock() }
        do {
            try file?.write(from: buffer)
        } catch {
            print("AudioFileWriter: write error: \(error)")
        }
    }

    func close() {
        lock.lock()
        defer { lock.unlock() }
        file = nil
    }
}

@MainActor
class AudioService: NSObject, ObservableObject {
    // MARK: - Published Properties

    @Published var isRecording = false
    @Published var isPlaying = false
    @Published var currentTime: TimeInterval = 0
    @Published var audioLevel: Float = 0       // RMS power in dB (for silence detection)
    @Published var peakLevel: Float = -160      // Peak power in dB (for visualizers)
    @Published var duration: TimeInterval = 0

    // MARK: - Recording (AVAudioEngine)

    private var audioEngine: AVAudioEngine?
    private var recordingStartTime: Date?
    private var currentRecordingURL: URL?

    /// Audio file for writing — accessed from both main actor (open/close)
    /// and audio render thread (write). Protected by nonisolated wrapper.
    private let fileWriter = AudioFileWriter()

    // MARK: - Playback (AVAudioPlayer — unchanged)

    private var audioPlayer: AVAudioPlayer?
    private var playbackTimer: Timer?

    // MARK: - Housekeeping Timer

    private var housekeepingTimer: Timer?

    // MARK: - Silence Detection

    private var silenceStartTime: Date?
    private let silenceThreshold: Float = -45.0  // dB level considered silence
    var silenceDuration: TimeInterval = 15.0     // Seconds of silence before auto-stop
    var onSilenceAutoStop: (() -> Void)?         // Callback when silence triggers stop

    // MARK: - Constants

    static let maxRecordingDuration: TimeInterval = 30 * 60 // 30 minutes

    // MARK: - Init

    override init() {
        super.init()
        setupInterruptionHandling()
    }

    // MARK: - Permissions

    func requestMicrophonePermission() async -> Bool {
        await withCheckedContinuation { continuation in
            if #available(iOS 17.0, *) {
                AVAudioApplication.requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            } else {
                AVAudioSession.sharedInstance().requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            }
        }
    }

    func setupAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try session.setActive(true)
        } catch {
            print("Failed to setup audio session: \(error)")
        }
    }

    // MARK: - Recording (AVAudioEngine + installTap)

    func startRecording() throws -> URL {
        let fileName = "\(UUID().uuidString).m4a"
        let url = Recording.recordingsDirectory.appendingPathComponent(fileName)
        currentRecordingURL = url

        let engine = AVAudioEngine()
        let inputNode = engine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)

        // Create output file using input node's sample rate (avoids resampling)
        let fileSettings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: inputFormat.sampleRate,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        try fileWriter.open(url: url, settings: fileSettings)

        // Install tap on input node: ~43Hz callbacks at 1024 buffer / 44.1kHz
        // The tap callback runs on the audio render thread (real-time priority)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: inputFormat) { [weak self] buffer, _ in
            self?.processPCMBuffer(buffer)
        }

        try engine.start()
        audioEngine = engine
        recordingStartTime = Date()

        isRecording = true
        currentTime = 0
        silenceStartTime = nil

        startHousekeepingTimer()
        playRecordStartSound()

        // Start Live Activity for Dynamic Island
        LiveActivityManager.shared.startRecordingActivity()

        return url
    }

    func stopRecording() -> (url: URL, duration: TimeInterval)? {
        guard isRecording else { return nil }

        let duration: TimeInterval
        if let start = recordingStartTime {
            duration = Date().timeIntervalSince(start)
        } else {
            duration = 0
        }

        // Tear down audio engine
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil
        fileWriter.close()
        recordingStartTime = nil

        stopHousekeepingTimer()
        isRecording = false
        audioLevel = 0
        peakLevel = -160

        playRecordStopSound()

        // End Live Activity
        LiveActivityManager.shared.endRecordingActivity()

        if let url = currentRecordingURL {
            return (url, duration)
        }
        return nil
    }

    func cancelRecording() {
        guard isRecording else { return }

        // Tear down audio engine
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil
        fileWriter.close()
        recordingStartTime = nil

        stopHousekeepingTimer()
        isRecording = false
        audioLevel = 0
        peakLevel = -160

        // End Live Activity
        LiveActivityManager.shared.endRecordingActivity()

        // Delete the cancelled recording file
        if let url = currentRecordingURL {
            try? FileManager.default.removeItem(at: url)
        }
        currentRecordingURL = nil
    }

    // MARK: - PCM Buffer Processing (runs on audio render thread)

    /// Processes raw PCM audio buffers from the engine tap.
    /// Computes true RMS and peak from actual waveform samples using Accelerate.
    /// Called at ~43Hz (1024 samples at 44.1kHz) on the audio render thread.
    private nonisolated func processPCMBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData else { return }
        let samples = channelData[0]  // Channel 0 (mono)
        let count = Int(buffer.frameLength)
        guard count > 0 else { return }

        // Write PCM to file (AVAudioFile handles float→AAC conversion)
        fileWriter.write(buffer)

        // True RMS from raw PCM samples (Accelerate/vDSP)
        var rms: Float = 0
        vDSP_rmsqv(samples, 1, &rms, vDSP_Length(count))
        let rmsDB = rms > 0 ? 20 * log10(rms) : -160

        // True peak from raw PCM samples (absolute max magnitude)
        var peak: Float = 0
        vDSP_maxmgv(samples, 1, &peak, vDSP_Length(count))
        let peakDB = peak > 0 ? 20 * log10(peak) : -160

        // Publish to main thread for visualizers
        Task { @MainActor [weak self] in
            self?.audioLevel = rmsDB
            self?.peakLevel = peakDB
        }
    }

    // MARK: - Playback (unchanged)

    func play(url: URL, rate: Float = 1.0) throws {
        stop()

        audioPlayer = try AVAudioPlayer(contentsOf: url)
        audioPlayer?.delegate = self
        audioPlayer?.enableRate = true
        audioPlayer?.rate = rate
        audioPlayer?.prepareToPlay()
        audioPlayer?.play()

        duration = audioPlayer?.duration ?? 0
        isPlaying = true

        startPlaybackTimer()
        playTapeStartSound()
    }

    func pause() {
        audioPlayer?.pause()
        isPlaying = false
        stopPlaybackTimer()
    }

    func resume() {
        audioPlayer?.play()
        isPlaying = true
        startPlaybackTimer()
    }

    func stop() {
        audioPlayer?.stop()
        audioPlayer = nil
        isPlaying = false
        currentTime = 0
        stopPlaybackTimer()
    }

    func seek(to time: TimeInterval) {
        audioPlayer?.currentTime = time
        currentTime = time
    }

    func setPlaybackRate(_ rate: Float) {
        audioPlayer?.rate = rate
    }

    func setVolume(_ volume: Float) {
        audioPlayer?.volume = volume
    }

    func skipForward(_ seconds: TimeInterval = 10) {
        guard let player = audioPlayer else { return }
        let newTime = min(player.currentTime + seconds, player.duration)
        seek(to: newTime)
    }

    func skipBackward(_ seconds: TimeInterval = 10) {
        guard let player = audioPlayer else { return }
        let newTime = max(player.currentTime - seconds, 0)
        seek(to: newTime)
    }

    // MARK: - Sound Effects

    private func playRecordStartSound() {
        // TODO: Play tape motor start sound
        HapticService.shared.playRecordStart()
    }

    private func playRecordStopSound() {
        // TODO: Play tape motor stop sound
        HapticService.shared.playRecordStop()
    }

    private func playTapeStartSound() {
        // TODO: Play tape playback start sound
    }

    // MARK: - Housekeeping Timer (20Hz — non-visualizer work only)

    private func startHousekeepingTimer() {
        housekeepingTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateHousekeeping()
            }
        }
    }

    private func stopHousekeepingTimer() {
        housekeepingTimer?.invalidate()
        housekeepingTimer = nil
    }

    private func updateHousekeeping() {
        guard isRecording else { return }

        // Track recording duration
        if let start = recordingStartTime {
            currentTime = Date().timeIntervalSince(start)
        }

        // Update Live Activity with audio level
        LiveActivityManager.shared.setAudioLevel(audioLevel)

        // Check for stop request from Dynamic Island widget
        checkForWidgetStopRequest()

        // Silence detection and max duration
        checkSilence()
        checkMaxDuration()
    }

    // MARK: - Silence Detection

    private func checkSilence() {
        if audioLevel < silenceThreshold {
            if silenceStartTime == nil {
                silenceStartTime = Date()
            } else if let startTime = silenceStartTime,
                      Date().timeIntervalSince(startTime) >= silenceDuration {
                silenceStartTime = nil
                onSilenceAutoStop?()
            }
        } else {
            silenceStartTime = nil
        }
    }

    private func checkMaxDuration() {
        if currentTime >= Self.maxRecordingDuration {
            _ = stopRecording()
        }
    }

    // MARK: - Playback Timer

    private func startPlaybackTimer() {
        playbackTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updatePlayback()
            }
        }
    }

    private func stopPlaybackTimer() {
        playbackTimer?.invalidate()
        playbackTimer = nil
    }

    private func updatePlayback() {
        guard let player = audioPlayer, isPlaying else { return }
        currentTime = player.currentTime
    }

    // MARK: - Audio Session Interruption Handling

    private func setupInterruptionHandling() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleInterruption),
            name: AVAudioSession.interruptionNotification,
            object: nil
        )
    }

    @objc nonisolated private func handleInterruption(_ notification: Notification) {
        guard let info = notification.userInfo,
              let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }

        Task { @MainActor [weak self] in
            guard let self else { return }
            if type == .began {
                // Phone call, Siri, etc. — stop recording gracefully
                if self.isRecording {
                    _ = self.stopRecording()
                }
            }
            // Note: .ended case — we don't auto-resume recording after interruption.
            // User should explicitly start a new recording.
        }
    }

    // MARK: - Widget Communication

    /// Check if the Dynamic Island widget requested to stop recording
    private func checkForWidgetStopRequest() {
        let defaults = UserDefaults(suiteName: "group.com.mididea.shared")
        if defaults?.bool(forKey: "stopRecordingRequested") == true {
            // Clear the flag first
            defaults?.removeObject(forKey: "stopRecordingRequested")
            defaults?.synchronize()

            // Stop the recording
            _ = stopRecording()
        }
    }
}

// MARK: - AVAudioPlayerDelegate

extension AudioService: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            isPlaying = false
            currentTime = 0
            stopPlaybackTimer()
        }
    }
}
