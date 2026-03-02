# Voice2Text - Project Context

## Overview
macOS Menu Bar + Dock voice-to-text app built with SwiftUI + AVAudioEngine + whisper.cpp.
Shows in both the menu bar (MenuBarExtra) and the Dock.

## Tech Stack
- **UI**: SwiftUI MenuBarExtra (macOS 13+)
- **Audio**: AVAudioEngine with AVAudioConverter (resample to 16kHz mono Float32)
- **STT Engines**: whisper.cpp (offline) and Apple Speech Recognition (online, streaming)
- **Build**: xcodegen (`project.yml` → `.xcodeproj`)
- **Requirements**: macOS 14+, Xcode 15+
- **Sandbox**: App Sandbox enabled with audio-input + network-client entitlements

## Current Status: Dual STT Engine Support
Full voice-to-text pipeline working with two engines:
- **Whisper**: record → resample → whisper inference → script conversion → display
- **Apple Speech**: record → stream buffers → real-time recognition → script conversion → display

Models downloaded on-demand from HuggingFace to `~/Library/Application Support/Voice2Text/`.

### Known Bugs
- **Dock icon click does not reopen main window**: `applicationShouldHandleReopen` IS called (confirmed via os_log), but the SwiftUI `Window` scene destroys the NSWindow on close. `canBecomeMain` finds no windows. `openWindow(id:)` is only available inside SwiftUI views, not from AppDelegate.
  - **Next approach to try**: Use a `@Published` flag on `AppState` set by AppDelegate, observed by a background/invisible SwiftUI view that calls `openWindow(id:)`, OR use `NSWindow` hiding instead of SwiftUI Window close.

### Completed Files
| File | Purpose |
|------|---------|
| `Voice2Text/Voice2TextApp.swift` | @main entry point, MenuBarExtra + Window scene |
| `Voice2Text/AppState.swift` | Shared ObservableObject: recording, transcription, model management, dual STT engines, script conversion, debug logging |
| `Voice2Text/MenuBarView.swift` | Menu bar dropdown: Start/Stop, model picker, script toggle, Dev Mode, Output Script, Open Window, Quit |
| `Voice2Text/ContentView.swift` | Main window: model picker, STT engine picker, script picker, status indicator, editable transcription, Copy button, debug log |
| `Voice2Text/AudioRecorder.swift` | AVAudioEngine + AVAudioConverter (16kHz mono Float32), dual-purpose tap for whisper + Apple Speech |
| `Voice2Text/WhisperBridge.swift` | Swift wrapper around whisper.cpp C API: load model, run inference on background queue |
| `Voice2Text/AppleSpeechRecognizer.swift` | Apple SFSpeechRecognizer wrapper: streaming recognition with partial results |
| `Voice2Text/AnthropicClient.swift` | Claude API client for text reformatting (feature currently greyed out) |
| `Voice2Text/Voice2Text-Bridging-Header.h` | `#include "whisper.h"` for Swift-C interop |
| `Voice2Text/AppDelegate.swift` | Handles Dock icon click to reopen main window |
| `Voice2Text/WindowAccessor.swift` | Captures NSWindow reference for AppDelegate |
| `Voice2Text/Info.plist` | NSMicrophoneUsageDescription, NSSpeechRecognitionUsageDescription |
| `Voice2Text/Voice2Text.entitlements` | App Sandbox + audio-input + network-client |
| `Voice2Text/Assets.xcassets/Contents.json` | Asset catalog stub |
| `Whisper/lib/` | Pre-built static libraries (libwhisper, libggml, libggml-base, libggml-cpu, libggml-metal, libggml-blas) |
| `Whisper/include/` | Header files (whisper.h, ggml*.h) |
| `project.yml` | xcodegen spec with bridging header, library paths, SDK dependencies |

## Architecture Notes
- `AppState` is the single source of truth, shared via `@EnvironmentObject`
- `AudioRecorder` is owned by `AppState` as a single instance — no duplicates
- `AudioRecorder` resamples mic input to 16kHz mono Float32 via `AVAudioConverter`
- `AudioRecorder` supports an optional `tapHandler` to forward raw buffers to Apple Speech
- `WhisperBridge` runs inference on a dedicated background `DispatchQueue`
- Whisper uses `language="auto"` for mixed Chinese+English speech
- If whisper outputs non-Chinese/English text (wrong language detection), auto-retries with `language="zh"`
- Apple Speech uses `zh-Hant` locale which handles mixed Chinese+English natively
- Apple Speech requires network — NWPathMonitor detects connectivity in real-time
- Post-processing pipeline: STT output → Simplified/Traditional Chinese conversion
- Script conversion uses Foundation `StringTransform` (`Hans-Hant` / `Hant-Hans`) — zero dependencies
- Model selection persisted via `UserDefaults`
- Models stored in `~/Library/Application Support/Voice2Text/`
- Available models: tiny, base, small, medium, large-v3-turbo
- Transcription text is editable by the user after transcription
- Dev mode (off by default) shows debug log panel with timestamped entries
- LLM reformat feature exists in code but is greyed out (company proxy limitation)

## TODO (Next Steps)
1. **FIX: Dock icon reopen window** — see Known Bugs above; highest priority
2. **WAV Export** — write audio buffer to file for batch processing
3. **Global Hotkey** — add global keyboard shortcut for start/stop recording
4. **UI Redesign** — separate model management into Settings page, keep main view focused on record+transcribe+copy
5. **LLM Reformat** — re-enable when API access is available (currently blocked by company proxy)

## Workflow Rules
- **Clarify before implementing**: when user input is ambiguous or unclear, do NOT guess — ask for clarification first and offer concrete options for the user to choose from.
- **Bug review before commit**: before any `git commit` + `git push`, perform a thorough bug review of all changed files (compilation, threading, SwiftUI lifecycle, API usage, edge cases). Only commit after confirming no issues.
- **When user says "bye"**: must perform these actions before ending:
  1. Update `CLAUDE.md` (reflect latest project status, progress, TODOs)
  2. Update `README.md` (sync latest status and TODOs)
  3. Thorough bug review of all code
  4. `git add` + `git commit` + `git push`

## Notes
- Use `xcodegen generate` to regenerate `.xcodeproj` — never hand-edit `.pbxproj`
- Custom Info.plist keys are defined in `project.yml` `info.properties` so they survive regeneration
- **Language preference**: all saved files (code, docs, CLAUDE.md, README.md) in **English**. Conversations with the user in **Traditional Chinese (繁體中文)**.
- whisper.cpp static libs built with CMake for arm64, Metal GPU acceleration enabled
- Linker warnings about macOS version mismatch (26.0 vs 14.0) are harmless
- Company brconnector proxy only allows CLI tools — native app HTTP calls return 404
