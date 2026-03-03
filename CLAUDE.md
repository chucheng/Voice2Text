# Voice2Text - Project Context

## Overview
macOS Menu Bar + Dock voice-to-text app built with SwiftUI + AVAudioEngine + whisper.cpp.
Shows in both the menu bar (MenuBarExtra) and the Dock.
**Version: 1.2.0** — 99 Language Support release.

## Tech Stack
- **UI**: SwiftUI MenuBarExtra (macOS 13+)
- **Audio**: AVAudioEngine with AVAudioConverter (resample to 16kHz mono Float32)
- **STT Engines**: whisper.cpp (offline) and Apple Speech Recognition (online, streaming)
- **Global Hotkey**: Carbon `RegisterEventHotKey` API for system-wide key capture
- **Auto-Paste**: CGEvent simulation (⌘V) with Accessibility permission
- **Build**: xcodegen (`project.yml` → `.xcodeproj`)
- **Requirements**: macOS 14+, Xcode 15+
- **Sandbox**: App Sandbox enabled with audio-input + network-client entitlements

## Current Status: v1.2.0 — 99 Language Support + Global Hotkey + Dual STT
Full voice-to-text pipeline with two recording modes:
- **In-app**: Spacebar push-to-talk → transcribe → display
- **Global hotkey (⌘;)**: Hold from any app → floating panel → release → transcribe → auto-paste at cursor

STT engines:
- **Whisper**: record → resample → whisper inference → punctuation restore (Chinese only) → script conversion → display/paste
- **Apple Speech**: record → stream buffers → real-time recognition → script conversion → display/paste

99 languages supported via Whisper `language="auto"`. Punctuation server auto-skipped for non-Chinese text.
Models downloaded on-demand from HuggingFace to `~/Library/Application Support/Voice2Text/`.
Upgrade installs auto-detect existing models (no re-download needed).

### Punctuation Server
- Standalone BERT-based server for Chinese punctuation restoration
- Can run from source (`python scripts/punctuation_server.py`) or as packaged `.app`
- PyInstaller spec + build script in `scripts/` for packaging as `PunctuationServer.app`
- Models cached to `~/Library/Application Support/PunctuationServer/models/`
- Voice2Text auto-launches the server app if found in known locations
- `PunctuationClient.swift` handles health checks, restoration requests, and auto-launch

### Known Bugs
- None currently tracked

### Completed Files
| File | Purpose |
|------|---------|
| `Voice2Text/Voice2TextApp.swift` | @main entry point, MenuBarExtra + Window scene |
| `Voice2Text/AppState.swift` | Shared ObservableObject: recording, transcription, model management, dual STT engines, global hotkey integration, script conversion, keyboard shortcuts, debug logging |
| `Voice2Text/MenuBarView.swift` | Menu bar dropdown: Start/Stop, model picker, script toggle, Punctuation Restore, Open Window, Quit |
| `Voice2Text/ContentView.swift` | Main window: record button, waveform, status, editable transcription, Copy button, Settings shortcut |
| `Voice2Text/OnboardingView.swift` | First-launch wizard: welcome → model selection (with download detection) → downloading → permissions (Accessibility) |
| `Voice2Text/SettingsView.swift` | Settings: General (engine, script), Models, Shortcuts (hotkey, accessibility), Advanced (punctuation, dev mode) |
| `Voice2Text/GlobalHotkeyManager.swift` | Carbon hotkey registration/unregistration, HotkeyCombo (Codable), accessibility check, CGEvent paste simulation |
| `Voice2Text/FloatingRecordingPanel.swift` | NSPanel (nonactivatingPanel + hudWindow) floating indicator: recording/transcribing/done states |
| `Voice2Text/HotkeyRecorderView.swift` | SwiftUI custom key combo recorder with modifier requirement |
| `Voice2Text/RecordButton.swift` | Animated record button with pulse rings and spin ring states |
| `Voice2Text/WaveformView.swift` | Canvas-based animated audio waveform |
| `Voice2Text/TranscriptionView.swift` | Editable transcription text area |
| `Voice2Text/CopyButton.swift` | Copy-to-clipboard button with animation |
| `Voice2Text/AudioRecorder.swift` | AVAudioEngine + AVAudioConverter (16kHz mono Float32), dual-purpose tap for whisper + Apple Speech |
| `Voice2Text/WhisperBridge.swift` | Swift wrapper around whisper.cpp C API: load model, run inference, explicit freeModel() for clean shutdown |
| `Voice2Text/AppleSpeechRecognizer.swift` | Apple SFSpeechRecognizer wrapper: streaming recognition with partial results |
| `Voice2Text/PunctuationClient.swift` | HTTP client + auto-launcher for punctuation server |
| `Voice2Text/AnthropicClient.swift` | Claude API client for text reformatting (feature currently greyed out) |
| `Voice2Text/Voice2Text-Bridging-Header.h` | `#include "whisper.h"` for Swift-C interop |
| `Voice2Text/AppDelegate.swift` | Dock icon reopen + graceful shutdown (unregister hotkey, free model, stop recording) |
| `Voice2Text/WindowAccessor.swift` | Captures NSWindow reference for AppDelegate |
| `Voice2Text/Info.plist` | NSMicrophoneUsageDescription, NSSpeechRecognitionUsageDescription |
| `Voice2Text/Voice2Text.entitlements` | App Sandbox + audio-input + network-client |
| `Voice2Text/Assets.xcassets/` | Asset catalog with app icon (all macOS sizes) |
| `Whisper/lib/` | Pre-built static libraries (libwhisper, libggml, libggml-base, libggml-cpu, libggml-metal, libggml-blas) |
| `Whisper/include/` | Header files (whisper.h, ggml*.h) |
| `project.yml` | xcodegen spec with bridging header, library paths, SDK dependencies (incl. Carbon.framework) |
| `scripts/punctuation_server.py` | Chinese punctuation restoration server (Python) |
| `scripts/PunctuationServer.spec` | PyInstaller spec for building .app |
| `scripts/build_app.sh` | Build script for PunctuationServer.app |
| `scripts/build_dmg.sh` | Build Voice2Text.dmg for distribution |
| `scripts/requirements.txt` | Python dependencies (torch, transformers, pyinstaller) |

## Architecture Notes
- `AppState` is the single source of truth, shared via `@EnvironmentObject`
- `AudioRecorder` is owned by `AppState` as a single instance — no duplicates
- `AudioRecorder` resamples mic input to 16kHz mono Float32 via `AVAudioConverter`
- `AudioRecorder` supports an optional `tapHandler` to forward raw buffers to Apple Speech
- `WhisperBridge` runs inference on a dedicated background `DispatchQueue`
- `WhisperBridge.freeModel()` must be called before app termination to avoid C++ static destructor crash
- Whisper uses `language="auto"` for mixed Chinese+English speech
- If whisper outputs mixed Chinese + unexpected language text, auto-retries with `language="zh"` (only when Chinese chars present)
- Non-Chinese languages accepted as-is (no retry) — enables 99-language support
- `textContainsChinese()` helper gates both retry logic and punctuation server usage
- Apple Speech uses `zh-Hant` locale which handles mixed Chinese+English natively
- Apple Speech requires network — NWPathMonitor detects connectivity in real-time
- Post-processing pipeline: STT output → punctuation restore (optional) → Simplified/Traditional Chinese conversion
- Punctuation server auto-launched from `/Applications/`, `~/Applications/`, or bundle-adjacent location
- Script conversion uses Foundation `StringTransform` (`Hans-Hant` / `Hant-Hans`) — zero dependencies
- Model selection persisted via `UserDefaults`
- Models stored in `~/Library/Application Support/Voice2Text/`
- Available models: tiny, base, small, medium, large-v3-turbo
- Transcription text is editable by the user after transcription
- Dev mode (off by default) shows debug log panel with timestamped entries
- LLM reformat feature exists in code but is greyed out (company proxy limitation)
- Keyboard shortcuts: Spacebar push-to-talk, Cmd+C copies full transcription (or selection if any)
- Punctuation restore enabled by default when server is available; greyed out when unavailable; auto-skipped for non-Chinese text
- Output script (Simplified/Traditional Chinese) persisted via UserDefaults, default: Simplified
- App icon: blue gradient with microphone, sound waves, text lines, "V2T" label

### Global Hotkey Architecture
- `GlobalHotkeyManager` (singleton): Carbon `RegisterEventHotKey` for system-wide key capture
- `HotkeyCombo` (Codable): persisted to UserDefaults, default ⌘; (`kVK_ANSI_Semicolon` + `cmdKey`)
- Carbon events dispatched to main thread via `DispatchQueue.main.async`
- `kEventHotKeyPressed` → `AppState.globalHotkeyDown()` → start recording + show floating panel
- `kEventHotKeyReleased` → `AppState.globalHotkeyUp()` → stop recording + transcribe
- After transcription: `performAutoPaste()` → clipboard + CGEvent ⌘V (if Accessibility granted)
- `FloatingRecordingPanel`: NSPanel with `.nonactivatingPanel` + `.hudWindow` — does NOT steal focus from target app
- `isGlobalHotkeyActive` flag distinguishes global hotkey flow from in-app recording (auto-paste only runs for global)
- In-app recording (Spacebar/button) and global hotkey recording are mutually exclusive via `canToggle` + `isRecording` guards
- `applicationShouldTerminate` in AppDelegate cleans up Carbon hotkey before exit

## Security
- Punctuation server: body size limit (1MB), text length limit (50K chars), ThreadingHTTPServer
- AnthropicClient: warns at runtime if ANTHROPIC_BASE_URL uses plaintext HTTP
- Debug logs redacted: only char counts logged, no transcription content
- Hardened Runtime enabled; entitlements minimal (sandbox + audio-input + network-client)
- No hardcoded secrets in source code
- Accessibility permission: only used for CGEvent paste simulation, checked via `AXIsProcessTrusted()`
- Upgrade detection: `@AppStorage("accessibilityWasGranted")` tracks prior grant; guides user to remove+re-add in System Settings after upgrade
- Permission checks delayed 1s after init for SwiftUI alert readiness; also triggered after onboarding completion
- Remaining accepted risks: localhost HTTP for punctuation IPC, no model checksum verification

## TODO (Next Steps)
1. **WAV Export** — write audio buffer to file for batch processing
2. **UI Redesign** — separate model management into Settings page, keep main view focused on record+transcribe+copy
3. **LLM Reformat** — re-enable when API access is available (currently blocked by company proxy)
4. **Model checksum** — add SHA-256 verification for downloaded whisper models

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
- `completeOnboarding()` was removed in v1.1 — OnboardingView directly sets engine/model, `onboardingCompleted` only set at permissions step end
