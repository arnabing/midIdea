import SwiftUI

/// Routing view that switches between visualizer rendering implementations.
/// MeshGradient styles (1-4) go to LiquidAudioVisualizer.
/// New styles (5-7) each have dedicated views.
struct VisualizerContainer: View {
    let audioLevel: Float
    let frequencyBands: [Float]  // [bass, mid, treble] normalized 0-1
    let onsetBands: [Float]      // [bass, mid, treble] spectral flux onset 0-1
    let isRecording: Bool
    let isIdle: Bool
    var colorMode: VisualizerColorMode = .ocean
    var visualStyle: VisualizerStyle = .liquidOcean

    var body: some View {
        switch visualStyle {
        case .liquidOcean, .plasmaPulse, .breathingAura, .radiantPulse:
            LiquidAudioVisualizer(
                audioLevel: audioLevel,
                frequencyBands: frequencyBands,
                onsetBands: onsetBands,
                isRecording: isRecording,
                isIdle: isIdle,
                colorMode: colorMode,
                visualStyle: visualStyle
            )

        case .metalOrb:
            MetalOrbVisualizer(
                audioLevel: audioLevel,
                frequencyBands: frequencyBands,
                onsetBands: onsetBands,
                isRecording: isRecording
            )

        case .shaderGlow:
            ShaderEffectVisualizer(
                audioLevel: audioLevel,
                frequencyBands: frequencyBands,
                onsetBands: onsetBands,
                isRecording: isRecording,
                isIdle: isIdle
            )

        case .particleField:
            ParticleVisualizer(
                audioLevel: audioLevel,
                frequencyBands: frequencyBands,
                onsetBands: onsetBands,
                isRecording: isRecording,
                isIdle: isIdle
            )
        }
    }
}
