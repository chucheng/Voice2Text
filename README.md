# Voice2Text

A macOS menu bar app for voice-to-text transcription using whisper.cpp and Apple Speech Recognition, built with SwiftUI and AVAudioEngine.

## Features

- **Dual STT engines** — whisper.cpp (offline) and Apple Speech Recognition (online, streaming)
- **Mixed Chinese + English** speech recognition
- **Simplified/Traditional Chinese** output toggle
- **Multiple whisper models** — tiny, base, small, medium, large-v3-turbo
- **Auto language retry** — detects wrong language output and retries with Chinese
- **Editable transcription** — edit text after transcription
- **One-click copy** to clipboard
- **Dev mode** — debug log panel for troubleshooting
- Menu bar + Dock presence

## Prerequisites

- macOS 14+ (Sonoma)
- Xcode 15+
- [xcodegen](https://github.com/yonaskolb/XcodeGen) — install via `brew install xcodegen`

## Getting Started

```bash
# Generate the Xcode project
xcodegen generate

# Open in Xcode
open Voice2Text.xcodeproj

# Build & Run: Cmd+R in Xcode
```

On first launch, select a whisper model and click "Download". The model is saved to `~/Library/Application Support/Voice2Text/`.

## STT Engines

| Engine | Requires | Mode | Best For |
|--------|----------|------|----------|
| Whisper | Downloaded model | Batch (record then transcribe) | Offline use, accuracy |
| Apple Speech | Network connection | Streaming (real-time) | Quick dictation, live preview |

Both engines support mixed Chinese + English speech.

## Project Structure

```
Voice2Text/
├── Voice2TextApp.swift          # @main entry point, MenuBarExtra + Window
├── AppState.swift               # Shared state, transcription pipeline, model management
├── MenuBarView.swift            # Menu bar dropdown UI
├── ContentView.swift            # Main window: model picker, transcription editor, controls
├── AudioRecorder.swift          # AVAudioEngine + 16kHz resampling + Apple Speech tap
├── WhisperBridge.swift          # Swift wrapper around whisper.cpp C API
├── AppleSpeechRecognizer.swift  # Apple SFSpeechRecognizer wrapper
├── AnthropicClient.swift        # Claude API client (feature greyed out)
├── Voice2Text-Bridging-Header.h # C interop header
├── AppDelegate.swift            # Dock icon handler
├── WindowAccessor.swift         # NSWindow reference capture
├── Voice2Text.entitlements      # Sandbox: audio-input + network-client
└── Assets.xcassets/             # Asset catalog
Whisper/
├── lib/                         # Pre-built static libraries (whisper, ggml, metal, cpu, blas)
└── include/                     # Header files (whisper.h, ggml*.h)
project.yml                      # xcodegen spec
```

## How It Works

### Whisper Engine
1. **Record** — AVAudioEngine captures mic input, AVAudioConverter resamples to 16kHz mono Float32
2. **Transcribe** — whisper.cpp runs inference on background thread (Metal GPU accelerated)
3. **Validate** — if output contains unexpected languages, auto-retries with `language="zh"`
4. **Convert** — applies Simplified/Traditional Chinese conversion via Foundation StringTransform
5. **Display** — editable TextEditor lets you fix any remaining issues

### Apple Speech Engine
1. **Record + Recognize** — AVAudioEngine streams raw buffers to SFSpeechRecognizer in real-time
2. **Display** — partial results shown live, with script conversion applied
3. **Finalize** — recognition completes when recording stops

## Available Whisper Models

| Model | Size | Quality |
|-------|------|---------|
| Tiny | ~75 MB | Fastest, lowest quality |
| Base | ~142 MB | Good balance |
| Small | ~466 MB | Better accuracy |
| Medium | ~1.5 GB | High accuracy |
| Large v3 Turbo | ~1.6 GB | Best accuracy |

## Known Issues

- **Dock icon click does not reopen main window** — use "Open Window" from menu bar dropdown as workaround

## TODO

- [ ] Fix Dock icon reopen window
- [ ] WAV export for batch processing
- [ ] Global keyboard shortcut for start/stop
- [ ] UI redesign: separate settings from main workflow
- [ ] LLM text reformatting (blocked by company proxy)
