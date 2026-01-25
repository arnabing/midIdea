# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

midIDEA is a native iOS voice recorder app styled after the iconic Talkboy cassette recorder from Home Alone 2. Built with SwiftUI targeting iOS 17+.

## Current Status (Jan 2026)

- **Dual UI Modes**: 
    - **Realistic**: High-fidelity 3D rendering with metallic textures, depth effects, and accurate proportions.
    - **Cartoon**: Simplified, high-contrast UI using a flat image background with invisible touch targets (`TalkboyCartoonView`).
- **Background**: Implemented "iOS 26 Liquid Glass" effect (blurred, moving abstract blobs) for the Cartoon view.
- **Wave-like Features**:
    - **Auto-Transcription**: Recordings are immediately transcribed upon stopping.
    - **Quick Access**: Stopping a recording (or pressing Stop when idle) immediately opens the Library view.
- **Samples**: Long-press on Play trigger placeholder for "Home Alone 2" samples.
- **Hardware Integration**: Support for Action Button via AppIntents.

## Next Steps: Voice Keyboard Extension

Building a system-wide voice keyboard (like Wispr Flow) with on-device speech-to-text.

### Critical iOS Limitation
iOS keyboard extensions **cannot access the microphone** (Apple restriction since 2014). All voice keyboard apps use workarounds:
- Keyboard opens main app → records voice → transcribes → returns text to keyboard
- Action Button for "quick dictate to clipboard" anywhere

### Architecture Decision
Use **Apple SpeechAnalyzer** (iOS 26) - already integrated, faster than Whisper (55% faster per Apple benchmarks). No need for external models like Parakeet or WhisperKit.

### Keyboard Features Planned
1. **Two modes**: Full keyboard + voice OR voice-only bar (user switchable)
2. **AI polish**: Remove filler words, add punctuation, format based on context (email=formal, messages=casual)
3. **Recent transcripts**: Quick re-insertion of previous dictations
4. **Action Button**: Quick dictate to clipboard for any app

### Research References
- [FluidAudio SDK](https://github.com/FluidInference/FluidAudio) - Parakeet on CoreML (batch only, no streaming yet)
- [WhisperKit](https://github.com/argmaxinc/WhisperKit) - Whisper on CoreML
- [Apple SpeechAnalyzer WWDC25](https://developer.apple.com/videos/play/wwdc2025/277/) - Native, fastest option
- Wispr Flow / Willow both use **cloud processing**, not truly on-device

## Build Commands

```bash
# Build for iOS Simulator (no signing required)
xcodebuild build \
  -project midIDEA.xcodeproj \
  -scheme midIDEA \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
  CODE_SIGN_IDENTITY="" \
  CODE_SIGNING_REQUIRED=NO

# Clean build
xcodebuild clean -project midIDEA.xcodeproj -scheme midIDEA
```

Cloud builds via Codemagic (see `codemagic.yaml`) - pushes to `main` or `develop` trigger TestFlight deployment.

## Architecture

### State Management
- `RecordingStore` and `AudioService` are `@StateObject`s created at app root
- Injected via `@EnvironmentObject` throughout the view hierarchy
- Both classes are `@MainActor` isolated with `@Published` properties for reactive UI

### Folder Structure
```
midIDEA/
├── App/           # App entry point, ContentView
├── Features/
│   ├── Recorder/  # Main cassette UI (Realistic & Cartoon views)
│   └── Library/   # Recordings list, detail view
├── Services/      # AudioService, HapticService, TranscriptionService
├── Models/        # Recording model, RecordingStore
├── Intents/       # Action Button / Siri Shortcuts (AppIntents)
├── Extensions/    # Color+Theme
└── Resources/     # Assets (colors, icons)

Shared/                    # App Groups shared code (keyboard ↔ app)
├── SharedDefaults.swift   # Shared UserDefaults wrapper
└── SharedContainer.swift  # Shared file container access

midIDEAKeyboard/           # Custom keyboard extension (WIP)
├── KeyboardViewController.swift
├── KeyboardView.swift
└── Info.plist
```

### Key Services
- **AudioService**: Wraps AVAudioRecorder/AVAudioPlayer, handles metering, playback rate control
- **RecordingStore**: Persists recordings metadata to UserDefaults, manages audio file lifecycle
- **TranscriptionService**: On-device transcription via iOS 26 SpeechAnalyzer (with DictationTranscriber fallback)
- **AIService**: Apple Intelligence integration for summaries and key points
- **HapticService**: CoreHaptics feedback for record/playback actions

### App Groups (for Keyboard Extension)
- **Identifier**: `group.com.mididea.shared`
- **SharedDefaults**: UserDefaults suite for keyboard ↔ app communication
- **SharedContainer**: File access for shared recordings and temp audio

### Data Flow
Audio files stored in app's Documents directory. Recording metadata (JSON) stored in UserDefaults. Max recording: 30 minutes.

## Key Design Decisions

- **Hold-to-record UX**: Press and hold to record, release triggers 3-second countdown to save (tap to resume, swipe to cancel)
- **Action Button**: iOS 17+ AppIntents for quick recording from lock screen
- **On-device only**: Uses Apple Speech framework (no cloud transcription)
- **Single theme**: Talkboy-inspired retro cassette design (no theme switching in v1)

## Required Permissions

- `NSMicrophoneUsageDescription`: Voice recording
- `NSSpeechRecognitionUsageDescription`: On-device transcription

## Frameworks

SwiftUI, AVFoundation, Speech, AppIntents, CoreHaptics, UIKit (keyboard extension)

## URL Schemes

- `mididea://voice-input` - Triggers voice input from keyboard extension
- `mididea://voice-input?context=email` - With context hint for AI formatting

## Developer Account

- **Team**: THENEXTCO INC.
- **Provisioned Devices**: 19
- **Build Distribution**: Codemagic → TestFlight
