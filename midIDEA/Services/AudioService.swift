import AVFoundation
import Accelerate
import Combine

// MARK: - FFT Processor (thread-safe, real-time safe)

/// Result from FFT processing: normalized bands + spectral flux onset detection.
struct FFTResult {
    var bands: [Float]   // [bass, mid, treble] normalized 0-1
    var onsets: [Float]  // [bass, mid, treble] spectral flux onset 0-1
}

/// Computes 3-band frequency decomposition (bass/mid/treble) from PCM samples
/// with spectral flux onset detection for beat/transient awareness.
/// Pre-allocates all buffers once; processBands() does zero allocation.
/// Safe for the audio render thread (no @MainActor, no allocation in hot path).
private final class FFTProcessor: @unchecked Sendable {
    private let log2n: vDSP_Length
    private let fftSize: Int
    private let halfSize: Int
    private let fftSetup: FFTSetup

    // Pre-allocated buffers
    private var window: [Float]
    private var windowedSamples: [Float]
    private var realParts: [Float]
    private var imagParts: [Float]
    private var magnitudes: [Float]

    // Spectral flux onset detection: previous frame magnitudes for diff
    private var previousMagnitudes: [Float]

    // Onset normalization: short running-max per band (~0.47s = 20 frames at 43Hz)
    private let onsetHistoryCount = 20
    private var onsetHistory: [[Float]]  // [3][onsetHistoryCount]
    private var onsetHistoryIndex: Int = 0

    // Asymmetric exponential max tracker per band (replaces sliding window)
    // Attack: instant. Release: slow decay (~3s to drop 10dB at 43Hz).
    private var runningMax: [Float] = [-60, -60, -60]

    init(bufferSize: Int = 1024) {
        fftSize = bufferSize
        halfSize = bufferSize / 2
        log2n = vDSP_Length(log2(Double(bufferSize)))
        fftSetup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2))!

        window = [Float](repeating: 0, count: bufferSize)
        windowedSamples = [Float](repeating: 0, count: bufferSize)
        realParts = [Float](repeating: 0, count: halfSize)
        imagParts = [Float](repeating: 0, count: halfSize)
        magnitudes = [Float](repeating: 0, count: halfSize)
        previousMagnitudes = [Float](repeating: 0, count: halfSize)

        // Pre-compute Hann window
        vDSP_hann_window(&window, vDSP_Length(bufferSize), Int32(vDSP_HANN_NORM))

        // Initialize onset history
        onsetHistory = Array(repeating: Array(repeating: Float(0), count: onsetHistoryCount), count: 3)
    }

    deinit {
        vDSP_destroy_fftsetup(fftSetup)
    }

    /// Process PCM samples into 3 normalized frequency bands + onset detection.
    /// Returns FFTResult with bands (0...1) and onsets (0...1).
    /// - Parameter samples: Raw PCM float samples (mono)
    /// - Parameter count: Number of samples (should match fftSize)
    func processBands(_ samples: UnsafePointer<Float>, count: Int) -> FFTResult {
        let n = min(count, fftSize)

        // 1. Apply Hann window
        vDSP_vmul(samples, 1, window, 1, &windowedSamples, 1, vDSP_Length(n))

        // Zero-pad if count < fftSize
        if n < fftSize {
            for i in n..<fftSize {
                windowedSamples[i] = 0
            }
        }

        // 2. Pack into split complex format for real FFT
        // 3. Forward FFT (in-place)
        // 4. Compute magnitudes
        // Using withUnsafeMutableBufferPointer to satisfy pointer lifetime requirements
        realParts.withUnsafeMutableBufferPointer { realBuf in
            imagParts.withUnsafeMutableBufferPointer { imagBuf in
                windowedSamples.withUnsafeBufferPointer { sampleBuf in
                    sampleBuf.baseAddress!.withMemoryRebound(to: DSPComplex.self, capacity: halfSize) { complexPtr in
                        var split = DSPSplitComplex(realp: realBuf.baseAddress!, imagp: imagBuf.baseAddress!)
                        vDSP_ctoz(complexPtr, 2, &split, 1, vDSP_Length(halfSize))
                    }
                }

                var split = DSPSplitComplex(realp: realBuf.baseAddress!, imagp: imagBuf.baseAddress!)
                vDSP_fft_zrip(fftSetup, &split, 1, log2n, FFTDirection(kFFTDirection_Forward))

                magnitudes.withUnsafeMutableBufferPointer { magBuf in
                    vDSP_zvmags(&split, 1, magBuf.baseAddress!, 1, vDSP_Length(halfSize))
                }
            }
        }

        // 5. Spectral flux onset detection: sum of positive magnitude increases per band
        let bassEnd = min(12, halfSize)
        let midEnd = min(94, halfSize)
        let trebleEnd = halfSize

        var bassFlux: Float = 0
        var midFlux: Float = 0
        var trebleFlux: Float = 0

        for i in 0..<bassEnd {
            let diff = magnitudes[i] - previousMagnitudes[i]
            if diff > 0 { bassFlux += diff }
        }
        for i in bassEnd..<midEnd {
            let diff = magnitudes[i] - previousMagnitudes[i]
            if diff > 0 { midFlux += diff }
        }
        for i in midEnd..<trebleEnd {
            let diff = magnitudes[i] - previousMagnitudes[i]
            if diff > 0 { trebleFlux += diff }
        }

        // Copy current magnitudes to previous for next frame
        previousMagnitudes.withUnsafeMutableBufferPointer { prevBuf in
            magnitudes.withUnsafeBufferPointer { magBuf in
                prevBuf.baseAddress!.update(from: magBuf.baseAddress!, count: halfSize)
            }
        }

        // Normalize onset flux against short running-max window
        let rawOnsets = [bassFlux, midFlux, trebleFlux]
        var normalizedOnsets = [Float](repeating: 0, count: 3)
        for i in 0..<3 {
            onsetHistory[i][onsetHistoryIndex] = rawOnsets[i]
        }
        onsetHistoryIndex = (onsetHistoryIndex + 1) % onsetHistoryCount
        for i in 0..<3 {
            let maxFlux = onsetHistory[i].max() ?? 1
            if maxFlux > 0.001 {
                normalizedOnsets[i] = min(1.0, rawOnsets[i] / maxFlux)
            }
        }

        // 6. Sum into 3 bands for level
        var bassSum: Float = 0
        var midSum: Float = 0
        var trebleSum: Float = 0

        vDSP_sve(magnitudes, 1, &bassSum, vDSP_Length(bassEnd))
        if midEnd > bassEnd {
            vDSP_sve(&magnitudes[bassEnd], 1, &midSum, vDSP_Length(midEnd - bassEnd))
        }
        if trebleEnd > midEnd {
            vDSP_sve(&magnitudes[midEnd], 1, &trebleSum, vDSP_Length(trebleEnd - midEnd))
        }

        // RMS-like: sqrt of mean squared magnitude per band
        let bassRMS = bassEnd > 0 ? sqrt(bassSum / Float(bassEnd)) : 0
        let midRMS = (midEnd - bassEnd) > 0 ? sqrt(midSum / Float(midEnd - bassEnd)) : 0
        let trebleRMS = (trebleEnd - midEnd) > 0 ? sqrt(trebleSum / Float(trebleEnd - midEnd)) : 0

        // Convert to dB
        let bassDB = bassRMS > 0 ? 20 * log10(bassRMS) : -60
        let midDB = midRMS > 0 ? 20 * log10(midRMS) : -60
        let trebleDB = trebleRMS > 0 ? 20 * log10(trebleRMS) : -60

        let bandDBs = [bassDB, midDB, trebleDB]

        // 7. Asymmetric exponential max tracker per band
        // Attack: instant (snap to current if higher)
        // Release: slow exponential decay (~0.078 dB/frame, ~3s to drop 10dB at 43Hz)
        let decayPerFrame: Float = 0.078  // dB drop per frame at ~43Hz
        for i in 0..<3 {
            if bandDBs[i] > runningMax[i] {
                // Instant attack
                runningMax[i] = bandDBs[i]
            } else {
                // Slow release
                runningMax[i] -= decayPerFrame
                // Floor at -60dB
                runningMax[i] = max(-60, runningMax[i])
            }
        }

        // 8. Normalize with 40dB dynamic range (wider than old 28dB for music headroom)
        var normalized = [Float](repeating: 0, count: 3)
        for i in 0..<3 {
            let floor = runningMax[i] - 40  // 40dB range: transients have room above sustain
            let range = runningMax[i] - floor
            if range > 0.1 {
                normalized[i] = max(0, min(1, (bandDBs[i] - floor) / range))
            }
            // Gentler curve: preserves more dynamics with good PCM data
            normalized[i] = pow(normalized[i], 0.80) + (normalized[i] > 0 ? 0.02 : 0)
            normalized[i] = min(1.0, normalized[i])
        }

        return FFTResult(bands: normalized, onsets: normalizedOnsets)
    }

    /// Reset all state (e.g., when recording stops)
    func reset() {
        runningMax = [-60, -60, -60]
        for i in 0..<halfSize {
            previousMagnitudes[i] = 0
        }
        onsetHistoryIndex = 0
        for i in 0..<3 {
            for j in 0..<onsetHistoryCount {
                onsetHistory[i][j] = 0
            }
        }
    }
}

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
    @Published var frequencyBands: [Float] = [0, 0, 0]  // [bass, mid, treble] normalized 0-1
    @Published var onsetBands: [Float] = [0, 0, 0]      // [bass, mid, treble] spectral flux onset 0-1
    @Published var duration: TimeInterval = 0

    // MARK: - Recording (AVAudioEngine)

    private var audioEngine: AVAudioEngine?
    private var recordingStartTime: Date?
    private var currentRecordingURL: URL?

    /// Audio file for writing — accessed from both main actor (open/close)
    /// and audio render thread (write). Protected by nonisolated wrapper.
    private let fileWriter = AudioFileWriter()

    /// FFT processor for 3-band frequency decomposition.
    /// Runs on the audio render thread (real-time priority), pre-allocated.
    private let fftProcessor = FFTProcessor()

    // Adaptive loudness: sliding window for overall peak normalization
    private nonisolated(unsafe) var recentPeaks = [Float](repeating: -60, count: 60)
    private nonisolated(unsafe) var recentPeakIndex: Int = 0

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
        frequencyBands = [0, 0, 0]
        onsetBands = [0, 0, 0]

        // Reset FFT and adaptive loudness state
        fftProcessor.reset()
        recentPeaks = [Float](repeating: -60, count: 60)
        recentPeakIndex = 0

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
        frequencyBands = [0, 0, 0]
        onsetBands = [0, 0, 0]

        // Reset FFT and adaptive loudness state
        fftProcessor.reset()
        recentPeaks = [Float](repeating: -60, count: 60)
        recentPeakIndex = 0

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
    /// Computes true RMS, peak, and 3-band FFT from actual waveform samples using Accelerate.
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

        // 3-band FFT frequency decomposition + onset detection
        let fftResult = fftProcessor.processBands(samples, count: count)

        // Adaptive loudness normalization for overall peak
        recentPeaks[recentPeakIndex] = peakDB
        recentPeakIndex = (recentPeakIndex + 1) % recentPeaks.count

        // Publish to main thread for visualizers
        Task { @MainActor [weak self] in
            self?.audioLevel = rmsDB
            self?.peakLevel = peakDB
            self?.frequencyBands = fftResult.bands
            self?.onsetBands = fftResult.onsets
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
