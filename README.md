# Voice2Text

A macOS menu bar app for voice-to-text transcription using whisper.cpp, built with SwiftUI and AVAudioEngine.

## Features

- **Voice-to-text** with whisper.cpp (offline, on-device)
- **Mixed Chinese + English** speech recognition
- **Simplified/Traditional Chinese** output toggle
- **Sentence reformatting** via Apple NaturalLanguage framework
- **Multiple model support** — tiny, base, small, medium, large-v3-turbo
- **Editable transcription** — edit text after transcription
- **One-click copy** to clipboard
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

## Project Structure

```
Voice2Text/
├── Voice2TextApp.swift          # @main entry point, MenuBarExtra + Window
├── AppState.swift               # Shared state, transcription pipeline, model management
├── MenuBarView.swift            # Menu bar dropdown UI
├── ContentView.swift            # Main window: model picker, transcription editor, controls
├── AudioRecorder.swift          # AVAudioEngine + 16kHz resampling
├── WhisperBridge.swift          # Swift wrapper around whisper.cpp C API
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

1. **Record** — AVAudioEngine captures mic input, AVAudioConverter resamples to 16kHz mono Float32
2. **Transcribe** — whisper.cpp runs inference on background thread (Metal GPU accelerated)
3. **Validate** — if output contains unexpected languages, auto-retries with `language="zh"`
4. **Reformat** — Apple NLTokenizer re-segments sentences and adds missing punctuation
5. **Convert** — applies Simplified/Traditional Chinese conversion via Foundation StringTransform
6. **Display** — editable TextEditor lets you fix any remaining issues

## Available Models

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
