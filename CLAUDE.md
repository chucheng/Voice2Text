# Voice2Text - Project Context

## Overview
macOS Menu Bar + Dock voice-to-text app built with SwiftUI + AVAudioEngine + whisper.cpp.
Shows in both the menu bar (MenuBarExtra) and the Dock.
**Version: 2.4.0** — Whisper streaming (progressive transcription); What's New 5s auto-dismiss.

## Tech Stack
- **UI**: SwiftUI MenuBarExtra (macOS 13+)
- **Audio**: AVAudioEngine with AVAudioConverter (resample to 16kHz mono Float32)
- **STT Engines**: whisper.cpp (offline) and Apple Speech Recognition (online, streaming)
- **Global Hotkey**: Carbon `RegisterEventHotKey` API for system-wide key capture
- **Auto-Paste**: CGEvent simulation (⌘V) with Accessibility permission
- **Build**: xcodegen (`project.yml` → `.xcodeproj`)
- **Requirements**: macOS 14+, Xcode 15+
- **Sandbox**: App Sandbox enabled with audio-input + network-client entitlements

## Current Status: v1.8.0 — In-Process CoreML BERT Punctuation + What's New + Debug Log Window + LLM/BERT Exclusivity
Full voice-to-text pipeline with two recording modes:
- **In-app**: Spacebar push-to-talk → transcribe → display
- **Global hotkey (⌘;)**: Hold from any app → floating panel → release → transcribe → auto-paste at cursor

STT engines:
- **Whisper**: record → resample → streaming partial inference every 2s (rolling text) → release → final whisper inference → punctuation restore (Chinese only) → Post-Edit Revise (optional) → script conversion → display/paste
- **Apple Speech**: record → stream buffers → real-time recognition → script conversion → display/paste

**Post-Edit Revise** (optional): after transcription, send text through Claude API to improve clarity and flow. Configured in Settings > AI Services tab. API token stored in macOS Keychain. Custom prompt support. When enabled, BERT punctuation is skipped (LLM handles it). On LLM failure, falls back to BERT if available, then to raw text.

**What's New** screen: shown once after version update with 5-second countdown auto-dismiss. Reads from bundled `WhatsNew.json` (bilingual en/zh).

**Debug Log Window**: separate resizable window (opened from Settings > Advanced > Dev Mode). Logs only collected when Dev Mode is enabled (reduces overhead). Pipeline timing shows duration of each stage (Whisper, BERT, LLM, total). Copy All button for easy export.

UI language switchable between English and Simplified Chinese (persisted via UserDefaults, default follows system locale).
99 languages supported via Whisper `language="auto"`. Punctuation model auto-skipped for non-Chinese text.
Models downloaded on-demand from HuggingFace to `~/Library/Application Support/Voice2Text/`.
Upgrade installs auto-detect existing models (no re-download needed).

### Punctuation Restoration (CoreML)
- Built-in BERT-based Chinese punctuation restoration via CoreML (no external server)
- Model: `p208p2002/zh-wiki-punctuation-restore` converted to `.mlpackage` (float16)
- `WordPieceTokenizer.swift` loads `vocab.txt` from app bundle, implements subword tokenization with offset tracking
- `PunctuationRestorer.swift` handles CoreML inference, chunking for long text, label-to-punctuation mapping
- Model downloaded on-demand from GitHub Releases to `~/Library/Application Support/Voice2Text/zh-punctuation-bert.mlpackage`
- Download/delete from Settings > Advanced
- Legacy `PunctuationServer.app` auto-removed on first launch (migration)

### Known Bugs
- None currently tracked

### Completed Files
| File | Purpose |
|------|---------|
| `Voice2Text/Voice2TextApp.swift` | @main entry point, MenuBarExtra + Window + Debug Log Window scenes |
| `Voice2Text/Strings.swift` | UILanguage enum + L localization enum (~120 strings × 2 languages: English / 简体中文) |
| `Voice2Text/AppState.swift` | Shared ObservableObject: recording, transcription, model management, dual STT engines, global hotkey integration, script conversion, keyboard shortcuts, UI language, AI Services API config, Post-Edit Revise, custom prompt, What's New, debug logging |
| `Voice2Text/MenuBarView.swift` | Menu bar dropdown: Start/Stop, model picker, script toggle, Punctuation Restore, Open Window, Quit |
| `Voice2Text/ContentView.swift` | Main window: record button, waveform, status, editable transcription, Copy button, Settings shortcut, © copyright |
| `Voice2Text/OnboardingView.swift` | First-launch wizard: language picker → welcome → model selection (with download detection) → downloading → permissions (Accessibility) |
| `Voice2Text/SettingsView.swift` | Settings: General (language, engine, script), Models, Shortcuts (hotkey, accessibility), Advanced (punctuation, dev mode), AI Services (API credentials, Post-Edit Revise) |
| `Voice2Text/GlobalHotkeyManager.swift` | Carbon hotkey registration/unregistration, HotkeyCombo (Codable), accessibility check, CGEvent paste simulation |
| `Voice2Text/FloatingRecordingPanel.swift` | NSPanel (nonactivatingPanel + hudWindow) floating indicator: recording/transcribing/done states |
| `Voice2Text/HotkeyRecorderView.swift` | SwiftUI custom key combo recorder with modifier requirement |
| `Voice2Text/RecordButton.swift` | Animated record button with pulse rings and spin ring states |
| `Voice2Text/WaveformView.swift` | Canvas-based animated audio waveform |
| `Voice2Text/TranscriptionView.swift` | Editable transcription text area |
| `Voice2Text/CopyButton.swift` | Copy-to-clipboard button with animation |
| `Voice2Text/AudioRecorder.swift` | AVAudioEngine + AVAudioConverter (16kHz mono Float32), dual-purpose tap for whisper + Apple Speech |
| `Voice2Text/WhisperBridge.swift` | Swift wrapper around whisper.cpp C API: load model, run inference, explicit freeModel() for clean shutdown |
| `Voice2Text/LlamaBridge.swift` | Swift wrapper around llama.cpp C API: load GGUF model, chat prompt template, sampler chain, generate text, freeModel for clean shutdown |
| `Voice2Text/AppleSpeechRecognizer.swift` | Apple SFSpeechRecognizer wrapper: streaming recognition with partial results |
| `Voice2Text/WordPieceTokenizer.swift` | WordPiece tokenizer: loads vocab.txt from bundle, subword tokenization with offset tracking |
| `Voice2Text/PunctuationRestorer.swift` | CoreML BERT inference for Chinese punctuation restoration, chunking for long text |
| `Voice2Text/vocab.txt` | WordPiece vocabulary (21K tokens) bundled in app for tokenizer |
| `Voice2Text/AnthropicClient.swift` | Claude API client: APICheckResult enum, checkAPI(), reviseText(prompt:), configurable base URL/model/token |
| `Voice2Text/WhatsNewView.swift` | What's New overlay: version changelog display with 5s countdown auto-dismiss |
| `Voice2Text/WhatsNew.json` | Bundled changelog data (bilingual en/zh, all versions) |
| `Voice2Text/DebugLogWindow.swift` | Separate debug log window with Copy All, text selection |
| `Voice2Text/KeychainHelper.swift` | Minimal macOS Keychain wrapper: saveToken, loadToken, deleteToken |
| `Voice2Text/Voice2Text-Bridging-Header.h` | `#include "whisper.h"` + `#include "llama.h"` for Swift-C interop |
| `Voice2Text/AppDelegate.swift` | Dock icon reopen + graceful shutdown (unregister hotkey, free model, stop recording) |
| `Voice2Text/WindowAccessor.swift` | Captures NSWindow reference for AppDelegate |
| `Voice2Text/Info.plist` | NSMicrophoneUsageDescription, NSSpeechRecognitionUsageDescription |
| `Voice2Text/Voice2Text.entitlements` | App Sandbox + audio-input + network-client |
| `Voice2Text/Assets.xcassets/` | Asset catalog with app icon (all macOS sizes) |
| `Whisper/lib/` | Pre-built static libraries (libwhisper, libggml, libggml-base, libggml-cpu, libggml-metal, libggml-blas) |
| `Whisper/include/` | Header files (whisper.h, ggml*.h) |
| `LlamaCpp/lib/` | Pre-built static library (libllama.a) for llama.cpp |
| `LlamaCpp/include/` | Header file (llama.h) |
| `project.yml` | xcodegen spec with bridging header, library paths, SDK dependencies (incl. Carbon.framework) |
| `scripts/convert_punctuation_model.py` | Developer tool: convert PyTorch BERT → CoreML .mlpackage |
| `scripts/build_llama.sh` | Build llama.cpp (tag b8200) for macOS arm64 with Metal + BLAS |
| `scripts/build_whisper.sh` | Rebuild whisper.cpp (v1.8.3) against llama.cpp's ggml for ABI compatibility |
| `scripts/build_dmg.sh` | Build Voice2Text.dmg for distribution |

## Architecture Notes
- `AppState` is the single source of truth, shared via `@EnvironmentObject`
- `AudioRecorder` is owned by `AppState` as a single instance — no duplicates
- `AudioRecorder` resamples mic input to 16kHz mono Float32 via `AVAudioConverter`
- `AudioRecorder` supports an optional `tapHandler` to forward raw buffers to Apple Speech
- `WhisperBridge` runs inference on a dedicated background `DispatchQueue`
- `WhisperBridge.freeModel()` must be called before app termination to avoid C++ static destructor crash
- `LlamaBridge` runs inference on a dedicated serial `DispatchQueue`; uses `freeModelSync()` at termination
- `LlamaBridge` and whisper.cpp share the same ggml static libraries (built from llama.cpp's ggml to avoid symbol conflicts)
- Local LLM model load is guarded by `isLoadingLocalLLMModel` to prevent double-load from rapid clicks
- Model file validation: load failure auto-deletes corrupt files (both Whisper and Local LLM)
- Whisper uses `language="auto"` for mixed Chinese+English speech
- If whisper outputs mixed Chinese + unexpected language text, auto-retries with `language="zh"` (only when Chinese chars present)
- Non-Chinese languages accepted as-is (no retry) — enables 99-language support
- `textContainsChinese()` helper gates both retry logic and punctuation model usage
- Apple Speech uses `zh-Hant` locale which handles mixed Chinese+English natively
- Apple Speech requires network — NWPathMonitor detects connectivity in real-time
- Post-processing pipeline: when LLM enabled: STT output → Post-Edit Revise (LLM handles punctuation) → strip `<think>` tags (safety net) → on failure: BERT fallback → script conversion. When LLM disabled: STT output → BERT punctuation (optional, Chinese, CoreML) → script conversion
- Qwen 3.5 models: empty `<think>\n\n</think>\n\n` block appended to prompt after assistant turn start to disable reasoning mode; `<think>...</think>` tags stripped from output as safety net
- Punctuation model downloaded on-demand to `~/Library/Application Support/Voice2Text/zh-punctuation-bert.mlpackage`
- Script conversion uses Foundation `StringTransform` (`Hans-Hant` / `Hant-Hans`) — zero dependencies
- Model selection persisted via `UserDefaults`
- Models stored in `~/Library/Application Support/Voice2Text/`
- Available models: tiny, base, small, medium, large-v3-turbo
- Transcription text is editable by the user after transcription
- Dev mode: opens separate debug log window. Logs only collected when dev mode is enabled. Pipeline timing (Whisper/BERT/LLM/total) shown in dev mode
- Post-Edit Revise: optional Claude API integration, configured in Settings > AI Services
- API token stored in macOS Keychain (`kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`), never in UserDefaults or logs
- API check state machine: Unchecked → Checking → Valid(latencyMs) / Invalid(message); field changes reset to Unchecked
- Revise failure: falls back to BERT (if available + Chinese) then to raw text + transient orange banner (4s) + debug log entry; never permanently disables
- Custom revise prompt: persisted in UserDefaults (key: `"customRevisePrompt"`). Empty = use default. Reset to Default button in UI
- Whisper streaming: 2s repeating timer runs partial inference on accumulated samples during recording; partial results show as rolling text; skipped if < 1s audio; `isStreamingInference` guard prevents concurrent partials; timer stopped on release before final inference
- What's New: `lastSeenVersion` tracked via `@AppStorage`. `WhatsNew.json` loaded from bundle. WhatsNewView auto-dismisses after 5s countdown, tap to dismiss early
- Keyboard shortcuts: Spacebar push-to-talk, Cmd+C copies full transcription (or selection if any)
- Punctuation restore enabled by default when model is loaded; greyed out when model not downloaded; auto-skipped for non-Chinese text
- Output script (Simplified/Traditional Chinese) persisted via UserDefaults, default: Simplified
- App icon: blue gradient with microphone, sound waves, text lines, "V2T" label
- UI language (English / 简体中文) persisted via UserDefaults (key: `"uiLanguage"`), default follows system locale
- All UI strings centralized in `Strings.swift` `L` enum; `L.lang` reads `AppState.shared.uiLanguage`
- Language picker: segmented control on OnboardingView welcome step + Settings > General top section
- Copyright notice "© Chucheng Hsieh" shown in ContentView bottom toolbar center after first-use tooltip disappears
- Strings that stay English in both languages: WhisperModel.displayName, STTEngine.rawValue, OutputScript.rawValue, "V2T"

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
- AnthropicClient: rejects non-localhost plaintext HTTP base URLs via `isValidBaseURL()`; localhost HTTP allowed for dev setups
- API token stored in macOS Keychain with `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`; never in UserDefaults, logs, or error messages
- WhisperBridge: language parameter validated against allowlist before passing to C layer
- Clipboard auto-clear: after global hotkey auto-paste, clipboard is cleared after 30s (only if still contains our text)
- Debug logs redacted: only char counts logged, no transcription content
- Hardened Runtime enabled; entitlements minimal (sandbox + audio-input + network-client)
- No hardcoded secrets in source code
- Accessibility permission: only used for CGEvent paste simulation, checked via `AXIsProcessTrusted()`
- Upgrade detection: `@AppStorage("accessibilityWasGranted")` tracks prior grant; guides user to remove+re-add in System Settings after upgrade
- Permission checks delayed 1s after init for SwiftUI alert readiness; also triggered after onboarding completion
- Remaining accepted risks: no model checksum verification, CGEvent paste targets frontmost app without verification

## TODO (Next Steps)
1. **WAV Export** — write audio buffer to file for batch processing
2. **UI Redesign** — separate model management into Settings page, keep main view focused on record+transcribe+copy
3. **Model checksum** — add SHA-256 verification for downloaded whisper models

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
