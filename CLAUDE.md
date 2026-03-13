# Voice2Text - Project Context

## Overview
macOS Menu Bar + Dock voice-to-text app built with SwiftUI + AVAudioEngine + whisper.cpp.
**Version: 2.12.0** — UI Refinement, ⌘T Script Toggle, Audio Input Device Selection, Focus Guard, 129 automated tests.

## Tech Stack
- **UI**: SwiftUI MenuBarExtra (macOS 14+, Xcode 15+)
- **Audio**: AVAudioEngine + AVAudioConverter (16kHz mono Float32), CoreAudio device enumeration/selection/monitoring
- **STT**: whisper.cpp (offline, beam search, Metal GPU) + Apple Speech Recognition (online, streaming)
- **Global Hotkey**: Carbon `RegisterEventHotKey` for system-wide capture
- **Auto-Paste**: CGEvent ⌘V with Accessibility permission
- **Punctuation**: CoreML BERT (`zh-wiki-punctuation-restore`, Chinese only, on-demand download)
- **Post-Edit Revise**: Optional Claude API / local LLM (llama.cpp) for text improvement
- **Build**: xcodegen (`project.yml` → `.xcodeproj`), App Sandbox (audio-input + network-client)

## Recording Modes
- **In-app**: Spacebar push-to-talk → transcribe → display
- **Global hotkey (⌘;)**: Hold from any app → floating panel → release → transcribe → auto-paste at cursor

## Processing Pipeline
- **Whisper**: record → resample → noise calibration (300ms) → high-pass filter + RMS normalize → beam search → punctuation restore (Chinese) → Post-Edit Revise (optional) → script conversion → display/paste
- **Apple Speech**: record → stream buffers → real-time recognition → script conversion → display/paste
- **LLM enabled**: BERT skipped (LLM handles punctuation); on LLM failure: BERT fallback → raw text
- **Qwen 3.5**: empty `<think></think>` block disables reasoning; tags stripped from output

## Architecture
- `AppState` is single source of truth (`@EnvironmentObject`), owns `AudioRecorder` (single instance)
- `WhisperBridge` / `LlamaBridge` run on dedicated background `DispatchQueue`s; both must call `freeModel()` before termination
- LlamaBridge and whisper.cpp share ggml static libs (built from llama.cpp's ggml to avoid symbol conflicts)
- Whisper: `language="auto"`, auto-retries with `language="zh"` if mixed Chinese + unexpected language detected
- `textContainsChinese()` gates retry logic and punctuation model usage
- Apple Speech: `zh-Hant` locale, requires network (NWPathMonitor)
- Model file validation: load failure auto-deletes corrupt files
- UI language (English / 简体中文) via `Strings.swift` `L` enum, persisted in UserDefaults
- Models downloaded on-demand from HuggingFace to `~/Library/Application Support/Voice2Text/`
- What's New screen shown once per version update (5s countdown). Debug Log Window via Dev Mode.

### Global Hotkey Architecture
- `GlobalHotkeyManager` (singleton): Carbon hotkey → main thread dispatch
- Key down → `globalHotkeyDown()` → start recording + show floating panel + type placeholder at cursor
- Key up → `globalHotkeyUp()` → stop recording → transcribe → `performAutoPaste()` → backspace placeholder → ⌘V
- `FloatingRecordingPanel`: NSPanel `.nonactivatingPanel` + `.hudWindow` — never steals focus
- In-app and global recording mutually exclusive via `canToggle` + `isRecording` guards

### Focus Guard
- On hotkey down, captures frontmost app PID. If user switches away during transcription, falls back to clipboard-only + 3s deferred timer. Return within 3s → paste executes. Otherwise clipboard-only.

## Security
- API token in macOS Keychain (`kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`), never in UserDefaults/logs
- `AnthropicClient`: rejects non-localhost plaintext HTTP; localhost HTTP allowed for dev
- `WhisperBridge`: language parameter validated against allowlist
- Clipboard auto-clear 30s after auto-paste; debug logs redacted (char counts only)
- Hardened Runtime; minimal entitlements; no hardcoded secrets
- Accessibility: only for CGEvent paste, checked via `AXIsProcessTrusted()`
- Accepted risks: no model checksum verification

## TODO
1. **WAV Export** — write audio buffer to file for batch processing
2. **UI Redesign** — separate model management into Settings, simplify main view
3. **Model checksum** — SHA-256 verification for downloaded models

## Workflow Rules
- **Defensive coding**: guard all UI actions with full state checks; use `DispatchWorkItem` for cancellable timers; never force-unwrap system resources; `withAnimation` for transient state; clean up ALL flags on hardware changes; handle all `OSStatus` codes
- **Clarify before implementing**: ask for clarification on ambiguous input
- **Bug review before commit**: check compilation, threading, SwiftUI lifecycle, API usage, edge cases
- **When user says "bye"**: update CLAUDE.md + README.md → bug review → git commit + push

## Notes
- Use `xcodegen generate` — never hand-edit `.pbxproj`
- Info.plist keys in `project.yml` `info.properties`
- **Language**: files in English, conversations in Traditional Chinese (繁體中文)
- whisper.cpp static libs: CMake arm64, Metal GPU enabled
- Linker warnings about macOS version mismatch (26.0 vs 14.0) are harmless
