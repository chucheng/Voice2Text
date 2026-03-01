# Voice2Text - Project Context

## Overview
macOS Menu Bar voice-to-text app built with SwiftUI + AVAudioEngine.
Menu bar only — no Dock icon (LSUIElement=YES).

## Tech Stack
- **UI**: SwiftUI MenuBarExtra (macOS 13+)
- **Audio**: AVAudioEngine (not AVAudioRecorder) — flexible for future streaming to Whisper
- **Requirements**: macOS 14+, Xcode 15+
- **Sandbox**: App Sandbox enabled with audio-input entitlement

## Current Status: Scaffold Complete
All Swift source files and config files are created, but no `.xcodeproj` yet.
User must create an Xcode project manually and replace generated files (see README.md).

### Completed Files
| File | Purpose |
|------|---------|
| `Voice2Text/Voice2TextApp.swift` | @main entry point, MenuBarExtra + Window scene |
| `Voice2Text/AppState.swift` | Shared ObservableObject (isRecording, transcriptionText) |
| `Voice2Text/MenuBarView.swift` | Menu bar dropdown: Start/Stop, Output Script, Open Window, Quit |
| `Voice2Text/ContentView.swift` | Main window: recording status indicator + transcription placeholder + button |
| `Voice2Text/AudioRecorder.swift` | AVAudioEngine wrapper, mic permission request, startRecording/stopRecording stubs |
| `Voice2Text/Info.plist` | LSUIElement=YES, NSMicrophoneUsageDescription |
| `Voice2Text/Voice2Text.entitlements` | App Sandbox + audio-input |
| `Voice2Text/Assets.xcassets/Contents.json` | Asset catalog stub |

## Architecture Notes
- `AppState` shared across MenuBarView and ContentView via `@EnvironmentObject`
- `AudioRecorder` currently held as separate `@StateObject` instances in MenuBarView and ContentView (should be unified into AppState or a singleton)
- Recording installs an input tap but buffer is not processed yet

## TODO (Next Steps)
1. **Integrate Whisper** — implement speech-to-text (whisper.cpp or Apple Speech framework)
2. **WAV Export** — write audio buffer to file for batch processing
3. **Output Script** — copy/paste transcription results
4. **Global Hotkey** — add global keyboard shortcut for start/stop recording
5. **Unify AudioRecorder instance** — MenuBarView and ContentView currently hold separate instances

## Workflow Rules
- **Clarify before implementing**: when user input is ambiguous or unclear, do NOT guess — ask for clarification first and offer concrete options for the user to choose from.
- **When user says "bye"**: must perform these actions before ending:
  1. Update `CLAUDE.md` (reflect latest project status, progress, TODOs)
  2. Update `README.md` (sync latest status and TODOs)
  3. `git add` + `git commit` + `git push`

## Notes
- Never hand-generate `.xcodeproj`/`.pbxproj` — too fragile
- **Language preference**: all saved files (code, docs, CLAUDE.md, README.md) in **English**. Conversations with the user in **Traditional Chinese (繁體中文)**.
