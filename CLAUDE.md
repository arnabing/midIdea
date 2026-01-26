# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

midIDEA is a native iOS voice recorder app with AI-powered transcription and insights. Built with SwiftUI targeting iOS 26+ with Liquid Glass effects.

## Current Status (Jan 2026)

### UI Architecture
- **Recording-First Navigation**: Recording screen is the root view, sidebar slides in from left
- **iOS 26 Liquid Glass**: Glass effects on buttons (`.glassEffect(.regular.interactive())`)
- **LiquidAudioVisualizer**: Full-screen MeshGradient background (4x4 grid, 120Hz physics-based animation)
- **Live Activity / Dynamic Island**: Shows recording status when app is backgrounded

### Core Features
- **Auto-Transcription**: Recordings transcribed immediately via iOS 26 SpeechAnalyzer
- **AI Insights**: Apple Intelligence generates summaries and key points
- **Sidebar Navigation**: Swipe from left edge or tap hamburger to access recordings
- **Action Button**: iOS 17+ AppIntents for quick recording from lock screen

### Key Views
- `MainContainerView` - Root container with NavigationStack and sidebar overlay
- `RecordingRootView` - Main recording screen with visualizer, rotating prompts, record button
- `SidebarDrawer` - Recordings list that slides in from left
- `TranscriptDetailView` - View/edit transcript with playback controls (uses `recordingId` lookup for reactive updates)
- `LiquidAudioVisualizer` - Audio-reactive MeshGradient background (see below)
- `ThinkingGlimmer` - Claude-like transcription loading indicator with shimmer animation

### LiquidAudioVisualizer
Full-screen MeshGradient (4x4 grid, 16 points) with voice-reactive animation.

**Visual Styles** (3-finger tap to toggle):
- **Liquid Ocean**: Smooth horizontal wave bands, ocean color palette
- **Plasma Pulse**: High contrast, dramatic movement with peak explosions

**Technical Details**:
- Renders at 120Hz via `TimelineView(.animation)`
- `AudioInterpolator` smooths 20Hz audio data to 120Hz rendering
- Row clamping prevents mesh triangulation artifacts (Row 1: [0.12, 0.48], Row 2: [0.52, 0.88])
- Cached color palettes eliminate per-frame `Color(hex:)` parsing
- No `.drawingGroup()` or `.brightness()` modifiers (cause flickering)

### ThinkingGlimmer
Claude-like transcription loading indicator in `TranscriptBubbleView.swift`:
- **Shimmer animation**: Gradient mask sweeps across text using `LinearGradient` with animated phase
- **Rotating phrases**: Cycles through creative messages ("Transcribing...", "Listening closely...", "Processing audio...", etc.)
- **Usage**: `ThinkingGlimmer()` replaces static spinners during `.inProgress` transcription status

## Next Steps: Voice Keyboard Extension

Building a system-wide voice keyboard (like Wispr Flow) with on-device speech-to-text.

### Critical iOS Limitation
iOS keyboard extensions **cannot access the microphone** (Apple restriction since 2014). All voice keyboard apps use workarounds:
- Keyboard opens main app → records voice → transcribes → returns text to keyboard
- Action Button for "quick dictate to clipboard" anywhere

### Architecture Decision
Use **Apple SpeechAnalyzer** (iOS 26) - already integrated, faster than Whisper (55% faster per Apple benchmarks). No need for external models like Parakeet or WhisperKit.

## Build Commands

```bash
# Build for iOS Simulator (no signing required)
xcodebuild build \
  -project midIDEA.xcodeproj \
  -scheme midIDEA \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
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
- **Navigation passes `UUID` not `Recording`**: Detail views look up recordings by ID from store to receive live updates (e.g., transcription status changes)

### Folder Structure
```
midIDEA/
├── App/              # App entry point, ContentView
├── Features/
│   ├── Main/         # MainContainerView, RecordingRootView, SidebarDrawer
│   ├── Detail/       # TranscriptDetailView, TranscriptBubbleView, ThinkingGlimmer
│   ├── Recorder/     # Legacy recorder views (TalkboyRealisticView, etc.)
│   └── Minimal/      # LiquidAudioVisualizer, onboarding views
├── Services/         # AudioService, TranscriptionService, AIService
├── Models/           # Recording model, RecordingStore
├── Intents/          # Action Button / Siri Shortcuts (AppIntents)
├── Visualizer/       # LiquidAudioVisualizer (MeshGradient)
├── Extensions/       # Color+Theme, Font+Typography
└── Resources/        # Assets (colors, icons)

RecordingWidget/      # Widget extension for Live Activity / Dynamic Island
├── RecordingWidgetLiveActivity.swift
├── RecordingActivityAttributes.swift
└── StopRecordingIntent.swift

Shared/               # App Groups shared code
├── SharedDefaults.swift
└── SharedContainer.swift
```

### Key Services
- **AudioService**: Wraps AVAudioRecorder/AVAudioPlayer, handles metering, playback rate control
- **RecordingStore**: Persists recordings metadata to UserDefaults, manages audio file lifecycle
- **TranscriptionService**: On-device transcription via iOS 26 SpeechAnalyzer
- **AIService**: Apple Intelligence integration for summaries and key points
- **LiveActivityManager**: Manages Dynamic Island / Live Activity for recording status

### App Groups (for Widget Extension)
- **Identifier**: `group.com.mididea.shared`
- **SharedDefaults**: UserDefaults suite for widget ↔ app communication

### Data Flow
Audio files stored in app's Documents directory. Recording metadata (JSON) stored in UserDefaults. Max recording: 30 minutes.

## iOS 26 Liquid Glass Effects

### Button Styling
```swift
// Interactive glass button (record button, sidebar button)
.glassEffect(.regular.interactive(), in: .circle)

// All circular buttons use glass effect for consistent iOS 26 styling
// Sidebar button uses .foregroundStyle(.black.opacity(0.8)) for visibility
```

### Key Points
- Don't add `.shadow()` after `.glassEffect()` - glass has built-in depth
- Use `.allowsHitTesting(false)` on background views to let gestures pass through
- Use `.highPriorityGesture()` for edge swipe gestures to override system gestures

## Navigation Patterns

### Sidebar Gesture
- Edge swipe from left (40pt threshold) opens sidebar
- Uses `.highPriorityGesture()` on NavigationStack
- Only active when `navigationPath.isEmpty`

### Hidden Gestures
- **3-finger tap**: Toggle visualizer style (Liquid Ocean ↔ Plasma Pulse)

### Recording Flow
1. User taps record → `AudioService.startRecording()`
2. Live Activity starts (Dynamic Island shows REC + timer)
3. User taps stop → `AudioService.stopRecording()`
4. Recording saved → Navigate to `TranscriptDetailView(recordingId:)`
5. Auto-transcription begins → `ThinkingGlimmer` shows with shimmer animation
6. Transcription completes → AI summary generated

## Required Permissions

- `NSMicrophoneUsageDescription`: Voice recording
- `NSSpeechRecognitionUsageDescription`: On-device transcription

## Frameworks

SwiftUI, AVFoundation, Speech, AppIntents, CoreHaptics, ActivityKit, WidgetKit

## Developer Account

- **Team**: THENEXTCO INC.
- **Provisioned Devices**: 19
- **Build Distribution**: Codemagic → TestFlight
