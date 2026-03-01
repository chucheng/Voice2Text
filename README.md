# Voice2Text

A macOS menu bar app for voice-to-text transcription, built with SwiftUI and AVAudioEngine.

## Prerequisites

- macOS 14+ (Sonoma)
- Xcode 15+

## Getting Started

Since hand-generating a valid `.xcodeproj` is fragile, follow these steps:

1. Open Xcode → **File → New → Project**
2. Select **macOS → App**, click Next
3. Configure:
   - Product Name: `Voice2Text`
   - Organization Identifier: your reverse-domain (e.g. `com.yourname`)
   - Interface: **SwiftUI**
   - Language: **Swift**
4. Save the project to any location
5. Replace the generated Swift files with those from the `Voice2Text/` folder in this repo:
   - `Voice2TextApp.swift`
   - `AppState.swift`
   - `MenuBarView.swift`
   - `ContentView.swift`
   - `AudioRecorder.swift`
6. Replace `Info.plist` and the `.entitlements` file
7. Replace `Assets.xcassets/Contents.json`
8. In Xcode project settings, set the **Info.plist path** to `Voice2Text/Info.plist`
9. Under **Signing & Capabilities**, ensure the **Audio Input** entitlement is enabled

## Build & Run

1. Open the `.xcodeproj` in Xcode
2. Press `Cmd+R` to build and run
3. The app appears as a waveform icon in the menu bar (no Dock icon)

## Verification

- Click the menu bar icon → see Start/Stop, Output Script, Open Window, Quit
- Click Start → microphone permission dialog appears
- Click Open Window → main window shows recording status and transcription placeholder

## Project Structure

```
Voice2Text/
├── Voice2TextApp.swift     # @main entry point, MenuBarExtra + Window
├── AppState.swift          # Shared state (isRecording, transcriptionText)
├── MenuBarView.swift       # Menu bar dropdown: Start/Stop, Output Script, Open Window, Quit
├── ContentView.swift       # Main window: status indicator + transcription text + button
├── AudioRecorder.swift     # AVAudioEngine mic recording stub
├── Info.plist              # LSUIElement=YES, mic usage description
├── Voice2Text.entitlements # App Sandbox + audio-input
└── Assets.xcassets/        # Asset catalog
```

## Design Decisions

- **MenuBarExtra** (macOS 13+) — native SwiftUI menu bar API
- **AVAudioEngine** — more flexible than AVAudioRecorder, suitable for future streaming transcription
- **LSUIElement=YES** — menu bar only, no Dock icon
- **App Sandbox** — enabled with audio-input entitlement

## Current Status

**Scaffold complete.** The app structure is in place with:
- Menu bar icon and dropdown menu
- Start/Stop recording toggle (triggers mic permission)
- Main window with status indicator and transcription placeholder
- Audio engine input tap installed, but no transcription logic yet

## TODO

- [ ] Integrate Whisper (or other STT engine) for transcription
- [ ] Export audio buffer to WAV for batch processing
- [ ] Implement "Output Script" to copy/paste transcription results
- [ ] Add global keyboard shortcut for start/stop recording
- [ ] Unify AudioRecorder instance (currently separate in MenuBarView and ContentView)
