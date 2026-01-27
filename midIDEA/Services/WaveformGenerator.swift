import AVFoundation
import Accelerate

/// Generates normalized waveform samples from audio files
struct WaveformGenerator {

    /// Generate waveform samples from an audio file URL
    /// - Parameters:
    ///   - url: Audio file URL
    ///   - sampleCount: Number of bars to generate (default: 200)
    /// - Returns: Array of normalized amplitude values [0.0...1.0]
    static func generate(from url: URL, sampleCount: Int = 200) async throws -> [Float] {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let samples = try generateSamples(from: url, sampleCount: sampleCount)
                    continuation.resume(returning: samples)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /// Internal synchronous sample generation (runs on background thread)
    private static func generateSamples(from url: URL, sampleCount: Int) throws -> [Float] {
        // Open audio file
        let audioFile = try AVAudioFile(forReading: url)
        let format = audioFile.processingFormat
        let frameCount = UInt32(audioFile.length)

        guard frameCount > 0 else {
            return Array(repeating: 0.5, count: sampleCount)
        }

        // Calculate frames per sample
        let framesPerSample = Int(frameCount) / sampleCount

        // Read audio data
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        try audioFile.read(into: buffer)

        guard let channelData = buffer.floatChannelData else {
            return Array(repeating: 0.5, count: sampleCount)
        }

        let channelDataPointer = channelData[0]
        var samples: [Float] = []

        // Downsample and normalize
        for sampleIndex in 0..<sampleCount {
            let startFrame = sampleIndex * framesPerSample
            let endFrame = min(startFrame + framesPerSample, Int(frameCount))
            let frameRange = endFrame - startFrame

            guard frameRange > 0 else {
                samples.append(0.0)
                continue
            }

            // Calculate RMS (root mean square) for this segment
            var sum: Float = 0.0
            for frameIndex in startFrame..<endFrame {
                let sample = channelDataPointer[frameIndex]
                sum += sample * sample
            }

            let rms = sqrt(sum / Float(frameRange))
            let normalizedValue = min(1.0, max(0.0, rms * 5.0)) // Amplify for visibility
            samples.append(normalizedValue)
        }

        return samples
    }
}
