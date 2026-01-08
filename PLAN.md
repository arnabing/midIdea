# midIDEA - iOS App Implementation Plan

## App Overview

**App Name:** midIDEA

A nostalgic iOS voice recorder app styled after the iconic Talkboy cassette recorder from Home Alone 2. Features instant recording via iPhone Action Button, automatic transcription, and a recordings library.

---

## Core Features

### 1. Action Button Integration (Primary Entry Point)
- **Single press** → Instantly start recording (app launches into record mode)
- **Press again** → Stop recording, auto-transcribe
- Uses iOS 17+ Action Button API (`AppIntents` framework)
- Works from lock screen with proper permissions

### 2. Retro Cassette UI (Main Screen)
Inspired by the Talkboy reference images:

```
┌─────────────────────────────────────────┐
│  [■] [◄◄] [►►] [►]  [●] ← Record (red)  │  ← Top button bar
├─────────────────────────────────────────┤
│                                         │
│         ╭─────────────────╮             │
│         │  ◯ ═══════ ◯   │             │  ← Cassette window
│         │  (animated      │             │    (reels spin when
│         │   tape reels)   │             │     recording/playing)
│         ╰─────────────────╯             │
│                                         │
│      "midIDEA" (retro script font)      │
│                                         │
│   ┌─────────────────────────────┐       │
│   │ ▓▓▓▓▓▓▓▓▓░░░░░░░░░░░░░░░░░ │       │  ← VU meter / waveform
│   └─────────────────────────────┘       │
│                                         │
│        ⏱ 00:00:32                       │  ← Recording duration
│                                         │
│   (●) (speaker grille graphic)          │
│                                         │
└─────────────────────────────────────────┘
        ↕ Swipe up for recordings library
```

### 3. Recording Controls
- **Stop (■)** - Stop recording/playback
- **Rewind (◄◄)** - Skip back 10s or previous recording
- **Fast Forward (►►)** - Skip forward 10s or next recording
- **Play (►)** - Play current/selected recording
- **Record (●)** - **HOLD TO RECORD** button (see interaction below)

### 3a. Hold-to-Record Interaction
The record button uses a press-and-hold gesture with rich visual feedback:

```
┌─────────────────────────────────────────────────────────────┐
│  IDLE STATE                                                 │
│  ┌───────┐                                                  │
│  │   ●   │  Red button, subtle idle glow                    │
│  └───────┘                                                  │
├─────────────────────────────────────────────────────────────┤
│  TOUCH DOWN (Hold)                                          │
│  ┌─────────────┐                                            │
│  │  ╭─────╮    │  Button expands slightly                   │
│  │  │  ●  │    │  Bright red GLOW emanates outward          │
│  │  ╰─────╯    │  Recording starts IMMEDIATELY              │
│  └─────────────┘  Haptic: firm press feedback               │
├─────────────────────────────────────────────────────────────┤
│  RELEASE → 3-SECOND COUNTDOWN                               │
│                                                             │
│      ╭───────────────╮                                      │
│      │               │                                      │
│      │      (3)      │  Circle expands with countdown       │
│      │               │  Pulsing animation: 3... 2... 1...   │
│      ╰───────────────╯  Ring depletes like a timer          │
│                                                             │
│  • TAP AGAIN during countdown → RESUME recording            │
│  • LET IT COMPLETE → Finalize & auto-transcribe             │
│  • SWIPE AWAY → Cancel recording (discard)                  │
├─────────────────────────────────────────────────────────────┤
│  COUNTDOWN COMPLETE                                         │
│  Recording saved, transcription begins                      │
│  Haptic: success tap                                        │
│  Cassette "ejects" animation → shows transcript             │
└─────────────────────────────────────────────────────────────┘
```

**Why 3-second countdown:**
- Gives user a moment to continue if they released accidentally
- Creates anticipation/ritual around saving
- Clear cancel window (swipe away to discard)
- Feels like tape "winding down"

### 4. Cassette Animation Details
- Two tape reels that spin during recording/playback
- Speed varies based on playback position (like real tape)
- Tape "ribbon" moves between reels
- Satisfying mechanical feel with subtle haptics

### 5. Recordings Library (Swipe Up / Tab)
- List view styled like cassette tape labels
- Each recording shows:
  - Date/time
  - Duration
  - First line of transcript preview
  - Cassette tape icon
- Tap to select → loads into main player
- Swipe to delete
- Share button for transcript/audio

### 6. Transcription
- Auto-transcribe after recording stops
- Use Apple Speech framework (`SFSpeechRecognizer`) for on-device transcription
- Show transcript below cassette UI or in detail view
- Copy transcript button
- Edit transcript capability

---

## Technical Architecture

### Project Structure
```
CassetteRecorder/
├── App/
│   ├── CassetteRecorderApp.swift       # App entry point
│   └── AppDelegate.swift               # Action Button handling
├── Features/
│   ├── Recorder/
│   │   ├── RecorderView.swift          # Main cassette UI
│   │   ├── RecorderViewModel.swift     # Recording logic
│   │   ├── CassetteView.swift          # Animated cassette component
│   │   ├── VUMeterView.swift           # Audio level visualization
│   │   └── ControlButtonsView.swift    # Transport controls
│   ├── Library/
│   │   ├── LibraryView.swift           # Recordings list
│   │   ├── LibraryViewModel.swift
│   │   └── RecordingRowView.swift      # Individual recording cell
│   └── Transcription/
│       ├── TranscriptionService.swift  # Speech-to-text
│       └── TranscriptView.swift        # Display/edit transcript
├── Services/
│   ├── AudioRecorderService.swift      # AVAudioRecorder wrapper
│   ├── AudioPlayerService.swift        # AVAudioPlayer wrapper
│   └── StorageService.swift            # Core Data / file management
├── Models/
│   ├── Recording.swift                 # Recording data model
│   └── CassetteRecorder.xcdatamodeld   # Core Data model
├── Intents/
│   ├── RecordIntent.swift              # Action Button intent
│   └── IntentShortcuts.swift           # Siri shortcuts
├── Resources/
│   ├── Assets.xcassets                 # Images, colors
│   ├── Fonts/                          # Retro fonts
│   └── Sounds/                         # Click sounds, tape sounds
└── Extensions/
    └── ...
```

### Key Frameworks
| Framework | Purpose |
|-----------|---------|
| SwiftUI | UI layer |
| AVFoundation | Audio recording/playback |
| Speech | On-device transcription |
| AppIntents | Action Button integration |
| CoreData | Local storage |
| CoreHaptics | Tactile feedback |

### Data Model
```swift
struct Recording: Identifiable {
    let id: UUID
    let createdAt: Date
    let duration: TimeInterval
    let audioFileURL: URL
    var transcript: String?
    var transcriptionStatus: TranscriptionStatus
    var title: String?  // Optional user-provided title
}

enum TranscriptionStatus {
    case pending
    case inProgress
    case completed
    case failed(Error)
}
```

---

## UI Design Specifications

### Color Palette (Talkboy-inspired)
- **Primary body:** Silver/gray metallic (`#A8A9AD`)
- **Accent dark:** Charcoal (`#36454F`)
- **Record button:** Bright red (`#FF3B30`)
- **Play/controls:** Green (`#34C759`)
- **Speaker grille:** Dark gray (`#2C2C2E`)
- **Cassette window:** Cream/beige (`#F5F5DC`)
- **Tape reels:** Brown/black

### Typography
- **Logo/branding:** Custom retro script font (similar to Talkboy logo)
- **Controls:** System SF Pro with slight mechanical feel
- **Transcript:** SF Pro Text for readability

### Animations
1. **Tape reel rotation** - Continuous spin during record/play
2. **Recording light blink** - Red dot pulses when recording
3. **VU meter bounce** - Real-time audio level response
4. **Button press** - Slight depression effect + haptic
5. **Cassette load** - Tape "loads" animation when selecting recording

---

## Implementation Phases

### Phase 1: Core Recording (MVP)
- [ ] Project setup with SwiftUI
- [ ] Basic cassette UI (static)
- [ ] Audio recording with AVFoundation
- [ ] Audio playback
- [ ] Local file storage
- [ ] Basic recordings list

### Phase 2: Polish & Animation
- [ ] Animated tape reels
- [ ] VU meter with real audio levels
- [ ] Button haptics and sounds
- [ ] Recording light animation
- [ ] Cassette "load" transitions

### Phase 3: Transcription
- [ ] Integrate SFSpeechRecognizer
- [ ] Auto-transcribe on recording stop
- [ ] Display transcript in UI
- [ ] Copy transcript functionality
- [ ] Edit transcript

### Phase 4: Action Button & Shortcuts
- [ ] AppIntents for Action Button
- [ ] Start recording from lock screen
- [ ] Siri Shortcuts support
- [ ] Background recording handling

### Phase 5: Enhancements
- [ ] iCloud sync for recordings
- [ ] Share recordings/transcripts
- [ ] Tape "skins" / color themes
- [ ] Widget for quick record
- [ ] Apple Watch companion (future)

---

## Action Button Implementation Details

```swift
// RecordIntent.swift
import AppIntents

struct StartRecordingIntent: AppIntent {
    static var title: LocalizedStringResource = "Start Recording"
    static var description = IntentDescription("Start a new voice recording")

    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        // Signal app to start recording immediately
        RecordingCoordinator.shared.startRecordingFromIntent()
        return .result()
    }
}

// In App Shortcuts Provider
struct CassetteShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartRecordingIntent(),
            phrases: ["Record with \(.applicationName)"],
            shortTitle: "Record",
            systemImageName: "record.circle"
        )
    }
}
```

---

## Audio Recording Implementation

```swift
// AudioRecorderService.swift
import AVFoundation

class AudioRecorderService: ObservableObject {
    private var audioRecorder: AVAudioRecorder?
    @Published var isRecording = false
    @Published var currentTime: TimeInterval = 0
    @Published var audioLevel: Float = 0

    func startRecording() throws -> URL {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .default)
        try session.setActive(true)

        let url = getDocumentsDirectory()
            .appendingPathComponent("\(UUID().uuidString).m4a")

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        audioRecorder = try AVAudioRecorder(url: url, settings: settings)
        audioRecorder?.isMeteringEnabled = true
        audioRecorder?.record()
        isRecording = true

        startMetering()
        return url
    }

    func stopRecording() -> URL? {
        audioRecorder?.stop()
        isRecording = false
        return audioRecorder?.url
    }

    private func startMetering() {
        Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let self, self.isRecording else { return }
            self.audioRecorder?.updateMeters()
            self.audioLevel = self.audioRecorder?.averagePower(forChannel: 0) ?? -160
            self.currentTime = self.audioRecorder?.currentTime ?? 0
        }
    }
}
```

---

## Transcription Implementation

```swift
// TranscriptionService.swift
import Speech

class TranscriptionService {
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))

    func transcribe(audioURL: URL) async throws -> String {
        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            throw TranscriptionError.notAvailable
        }

        let request = SFSpeechURLRecognitionRequest(url: audioURL)
        request.shouldReportPartialResults = false
        request.requiresOnDeviceRecognition = true  // Privacy-friendly

        return try await withCheckedThrowingContinuation { continuation in
            recognizer.recognitionTask(with: request) { result, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                if let result, result.isFinal {
                    continuation.resume(returning: result.bestTranscription.formattedString)
                }
            }
        }
    }

    func requestAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }
}
```

---

## Required Permissions (Info.plist)

```xml
<key>NSMicrophoneUsageDescription</key>
<string>Record voice memos with the cassette recorder</string>

<key>NSSpeechRecognitionUsageDescription</key>
<string>Transcribe your recordings to text</string>
```

---

## Open Questions / Decisions Needed

### Branding & Identity
1. ~~**App Name:**~~ → **DECIDED: midIDEA**
2. **App Icon:** Cassette tape? The recorder device? Record button?

### Core UX Decisions
3. ~~**Action Button behavior:**~~ → **DECIDED: Single tap to start, double tap to stop**
   - Single tap starts recording immediately
   - Double tap stops and saves
   - Works from lock screen

4. ~~**Maximum recording length:**~~ → **DECIDED: 30 minute cap**

5. **What happens if recording during incoming call?**
   - Auto-save what was recorded?
   - Pause and resume after?

6. **Transcript editing:**
   - Allow inline editing of transcripts?
   - Or keep them read-only (source of truth is audio)?

7. ~~**Playback speed control:**~~ → **DECIDED: Yes, include slow-mo effect**
   - Classic Talkboy-style speed control
   - Slider for variable speed

### Library & Organization
8. ~~**Recording titles:**~~ → **DECIDED: Date/time only**
   - Simple, no manual naming required
   - Format: "Jan 8, 2026 at 3:42 PM"

9. **Search:**
   - Search transcript text?
   - Full-text search across all recordings?

10. **Folders/Tags:**
    - Simple flat list?
    - Allow organizing into folders?
    - Tags/labels?

### Visual & Audio Feedback
11. ~~**Sound effects:**~~ → **DECIDED: Yes**
    - Tape motor sounds during record/play
    - Button click sounds
    - Option to disable in settings

12. ~~**Cassette skins/themes:**~~ → **DECIDED: Single theme for v1**
    - Talkboy-inspired design only
    - Keep focused, maybe add more later

### Technical & Privacy
13. **Transcription service:**
    - Apple Speech only (on-device, private, free)?
    - Option for Whisper API (better accuracy, costs money, sends data)?
    - Both with toggle?

14. **Storage location:**
    - App sandbox only?
    - Option to save to Files app?
    - Auto-export to iCloud Drive?

### Business Model
15. ~~**Monetization:**~~ → **DECIDED: One-time purchase**
    - Simple paid app
    - No ads, no subscriptions
    - Price TBD ($2.99-$4.99 range)

16. **Cloud sync:**
    - iCloud only (simple)?
    - Cross-platform (needs backend)?
    - Skip for v1?

---

## Decisions Summary

| Decision | Choice |
|----------|--------|
| App name | **midIDEA** |
| Action Button | Single tap = start, Double tap = stop |
| Max length | 30 minutes |
| Playback speed | Yes, slow-mo effect included |
| Recording titles | Date/time only |
| Sound effects | Yes (with toggle) |
| Skins | Single Talkboy theme |
| Monetization | One-time purchase |

---

## Next Steps

1. Create new Xcode project with SwiftUI
2. Build static cassette UI mockup
3. Implement basic recording functionality
4. Add playback controls
5. Create recordings list view
6. Animate the cassette components
7. Integrate transcription
8. Add Action Button support
