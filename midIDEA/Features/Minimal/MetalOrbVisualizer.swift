//
//  MetalOrbVisualizer.swift
//  midIDEA
//
//  Based on ElevenLabs swift components (Apache 2.0 License)
//  Original work Copyright 2024 LiveKit, Inc.
//  Modifications Copyright 2025 Eleven Labs Inc.
//  Adapted for midIDEA: replaced LiveKit AudioTrack with AudioInterpolator.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//

import SwiftUI
import MetalKit
import simd

// MARK: - Uniforms (must match OrbShader.metal byte-for-byte, stride = 96)

struct OrbUniforms {
    var time: Float = 0
    var animation: Float = 0
    var inverted: Float = 0
    var _pad0: Float = 0
    var offsets: simd_float8 = .zero // only first 7 used
    var color1: simd_float4 = .zero
    var color2: simd_float4 = .zero
    var inputVolume: Float = 0
    var outputVolume: Float = 0
    var _pad1: SIMD2<Float> = .zero
}

// MARK: - sRGB → Linear conversion

@inline(__always)
private func sRGBToLinear(_ v: CGFloat) -> Float {
    if v <= 0.04045 { return Float(v / 12.92) }
    return Float(pow((v + 0.055) / 1.055, 2.4))
}

@inline(__always)
private func colorToSIMD4(_ color: Color) -> simd_float4 {
    let ui = UIColor(color)
    var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 1
    ui.getRed(&r, green: &g, blue: &b, alpha: &a)
    return .init(sRGBToLinear(r), sRGBToLinear(g), sRGBToLinear(b), Float(a))
}

// MARK: - Audio Processing

/// Maps normalized 0-1 audio level to visual intensity.
/// Uses gentle curve (pow 0.85) to preserve dynamic range.
/// Old curve (pow 0.6 * 1.8) mapped everything above -42dB to ~1.0,
/// crushing all speech dynamics into a flat line.
private func processAudioLevel(_ raw: Float) -> Float {
    min(max(pow(raw, 0.85) + 0.05, 0.0), 1.0)
}

// MARK: - Metal Orb View

struct MetalOrbVisualizer: View {
    let audioLevel: Float  // -60 to 0 dB
    let isRecording: Bool

    // ElevenLabs default colors (soft blue / periwinkle)
    private static let defaultColor1 = Color(red: 0.793, green: 0.863, blue: 0.988)
    private static let defaultColor2 = Color(red: 0.627, green: 0.725, blue: 0.820)

    var body: some View {
        GeometryReader { geo in
            let side = max(geo.size.width, geo.size.height)

            ZStack {
                Color.black.ignoresSafeArea()

                MetalOrbRepresentable(
                    audioLevel: audioLevel,
                    isRecording: isRecording,
                    color1: Self.defaultColor1,
                    color2: Self.defaultColor2
                )
                .frame(width: side, height: side)
                .position(x: geo.size.width / 2, y: geo.size.height / 2)
            }
        }
        .clipped()
        .ignoresSafeArea()
    }
}

// MARK: - UIViewRepresentable Wrapper

private struct MetalOrbRepresentable: UIViewRepresentable {
    let audioLevel: Float
    let isRecording: Bool
    let color1: Color
    let color2: Color

    func makeUIView(context: Context) -> MTKView {
        let mtkView = MTKView()
        mtkView.device = MTLCreateSystemDefaultDevice()
        mtkView.framebufferOnly = false
        mtkView.preferredFramesPerSecond = 60
        mtkView.colorPixelFormat = .bgra8Unorm
        mtkView.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        mtkView.isOpaque = false
        mtkView.backgroundColor = .clear
        mtkView.enableSetNeedsDisplay = false
        mtkView.isPaused = false
        mtkView.autoResizeDrawable = true

        let coordinator = context.coordinator
        coordinator.setupMetal(device: mtkView.device!)
        mtkView.delegate = coordinator

        return mtkView
    }

    func updateUIView(_ uiView: MTKView, context: Context) {
        context.coordinator.updateColors(color1: color1, color2: color2)
        context.coordinator.updateVolumes(level: audioLevel, isRecording: isRecording)
    }

    func makeCoordinator() -> OrbRenderer {
        OrbRenderer(color1: color1, color2: color2)
    }

    static func dismantleUIView(_ uiView: MTKView, coordinator: OrbRenderer) {
        uiView.isPaused = true
        uiView.delegate = nil
        coordinator.cleanup()
    }
}

// MARK: - Metal Renderer (Render Pipeline)

private class OrbRenderer: NSObject, MTKViewDelegate {
    private var device: MTLDevice?
    private var commandQueue: MTLCommandQueue?
    private var renderPipeline: MTLRenderPipelineState?
    private var vertexBuffer: MTLBuffer?

    private var startTime: CFTimeInterval = CACurrentMediaTime()
    private var animationTime: Float = 0

    private var uniforms = OrbUniforms()
    private let randomOffsets: [Float]

    // Target volumes set by updateVolumes (from SwiftUI thread).
    // draw() lerps toward these each frame for smooth animation
    // independent of SwiftUI's update cadence.
    private var targetInput: Float = 0.05
    private var targetOutput: Float = 0

    init(color1: Color, color2: Color) {
        self.randomOffsets = (0..<7).map { _ in Float.random(in: 0...(Float.pi * 2)) }
        super.init()
        uniforms.inputVolume = 0.05
        uniforms.outputVolume = 0
        updateColors(color1: color1, color2: color2)
    }

    func updateColors(color1: Color, color2: Color) {
        uniforms.color1 = colorToSIMD4(color1)
        uniforms.color2 = colorToSIMD4(color2)
    }

    func updateVolumes(level: Float, isRecording: Bool) {
        if isRecording {
            let normalized = (max(-60, min(0, level)) + 60) / 60
            let processed = processAudioLevel(normalized)
            targetInput = processed
            targetOutput = processed * 0.6
        } else {
            targetInput = 0.05
            targetOutput = 0
        }
    }

    func setupMetal(device: MTLDevice) {
        self.device = device
        self.commandQueue = device.makeCommandQueue()

        // Build full-screen quad vertex buffer
        let verts: [Float] = [
            -1,  1,
            -1, -1,
             1,  1,
             1, -1,
        ]
        vertexBuffer = device.makeBuffer(
            bytes: verts,
            length: verts.count * MemoryLayout<Float>.size,
            options: []
        )

        // Build render pipeline
        guard let library = device.makeDefaultLibrary(),
              let vertexFn = library.makeFunction(name: "orbVertexShader"),
              let fragmentFn = library.makeFunction(name: "orbFragmentShader") else {
            print("MetalOrbVisualizer: Failed to load shader functions")
            return
        }

        let desc = MTLRenderPipelineDescriptor()
        desc.vertexFunction = vertexFn
        desc.fragmentFunction = fragmentFn
        desc.colorAttachments[0].pixelFormat = .bgra8Unorm

        do {
            renderPipeline = try device.makeRenderPipelineState(descriptor: desc)
        } catch {
            print("MetalOrbVisualizer: Failed to create pipeline: \(error)")
        }

        // Debug: verify uniform stride matches Metal layout
        assert(MemoryLayout<OrbUniforms>.stride == 96,
               "OrbUniforms stride is \(MemoryLayout<OrbUniforms>.stride), expected 96")
    }

    func cleanup() {
        renderPipeline = nil
        vertexBuffer = nil
        commandQueue = nil
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    func draw(in view: MTKView) {
        guard let pipeline = renderPipeline,
              let vertexBuffer = vertexBuffer,
              let drawable = view.currentDrawable,
              let rpd = view.currentRenderPassDescriptor,
              let commandBuffer = commandQueue?.makeCommandBuffer(),
              let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: rpd) else { return }

        let fps = max(view.preferredFramesPerSecond, 1)
        animationTime += (1.0 / Float(fps)) * 0.1

        uniforms.time = Float(CACurrentMediaTime() - startTime)
        uniforms.animation = animationTime
        uniforms.inverted = 0
        uniforms.offsets = simd_float8(
            randomOffsets[0], randomOffsets[1], randomOffsets[2], randomOffsets[3],
            randomOffsets[4], randomOffsets[5], randomOffsets[6], 0
        )

        // Asymmetric attack/release: fast rise (0.5), smooth decay (0.1).
        // Runs every Metal frame (60fps) independent of SwiftUI update cadence.
        let inputFactor: Float = targetInput > uniforms.inputVolume ? 0.5 : 0.1
        uniforms.inputVolume += (targetInput - uniforms.inputVolume) * inputFactor
        let outputFactor: Float = targetOutput > uniforms.outputVolume ? 0.5 : 0.1
        uniforms.outputVolume += (targetOutput - uniforms.outputVolume) * outputFactor

        encoder.setRenderPipelineState(pipeline)
        encoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)

        var u = uniforms
        encoder.setFragmentBytes(&u, length: MemoryLayout<OrbUniforms>.stride, index: 0)

        encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        encoder.endEncoding()

        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
}
