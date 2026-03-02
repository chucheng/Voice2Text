# Voice2Text

A macOS menu bar app for voice-to-text transcription using whisper.cpp and Apple Speech Recognition, built with SwiftUI and AVAudioEngine.

## Features

- **Dual STT engines** — whisper.cpp (offline) and Apple Speech Recognition (online, streaming)
- **Mixed Chinese + English** speech recognition
- **Simplified/Traditional Chinese** output toggle via Foundation StringTransform
- **Multiple whisper models** — tiny, base, small, medium, large-v3-turbo (downloaded on-demand)
- **Auto language retry** — detects wrong language output and retries with Chinese
- **Push-to-talk** — hold Spacebar to record, release to transcribe
- **Punctuation restoration** — BERT-based server adds punctuation automatically (enabled by default when server available)
- **Editable transcription** — edit text inline after transcription
- **Cmd+C smart copy** — copies full transcription when nothing selected, or copies selection
- **Dev mode** — debug log panel for troubleshooting
- Custom app icon
- Menu bar + Dock presence

## Prerequisites

- macOS 14+ (Sonoma)
- Xcode 15+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) — `brew install xcodegen`

## Getting Started

```bash
# Generate the Xcode project
xcodegen generate

# Open in Xcode
open Voice2Text.xcodeproj

# Build & Run: Cmd+R in Xcode
```

On first launch, select a whisper model and click "Download". Models are saved to `~/Library/Application Support/Voice2Text/`.

## Architecture

```
┌──────────────────────────────────────────────────────────────┐
│                        Voice2Text.app                        │
│                                                              │
│  ┌─────────────┐  ┌──────────────┐  ┌────────────────────┐  │
│  │ MenuBarView  │  │ ContentView  │  │   WindowAccessor   │  │
│  │ (MenuBarExtra│  │ (Main Window)│  │ (NSWindow capture) │  │
│  │  dropdown)   │  │              │  │                    │  │
│  └──────┬───────┘  └──────┬───────┘  └────────────────────┘  │
│         │                 │                                   │
│         └────────┬────────┘                                   │
│                  ▼                                            │
│  ┌──────────────────────────────┐                            │
│  │     AppState (singleton)     │ ◄── Single source of truth │
│  │                              │                            │
│  │  • Recording state           │                            │
│  │  • Transcription pipeline    │                            │
│  │  • Model management          │                            │
│  │  • Push-to-talk (Spacebar)   │                            │
│  │  • Post-processing pipeline  │                            │
│  └──────┬───────┬───────┬───────┘                            │
│         │       │       │                                    │
│         ▼       ▼       ▼                                    │
│  ┌──────────┐ ┌──────┐ ┌───────────────────┐                │
│  │  Audio   │ │Whisper│ │  Apple Speech     │                │
│  │ Recorder │ │Bridge │ │  Recognizer       │                │
│  │ (16kHz   │ │(C API)│ │  (SFSpeech)       │                │
│  │ resample)│ │       │ │                   │                │
│  └──────────┘ └──────┘ └───────────────────┘                │
└──────────────────────────────────────────────────────────────┘
                              │
           ┌──────────────────┼──────────────────┐
           ▼                  ▼                  ▼
  ┌─────────────────┐ ┌─────────────┐  ┌──────────────────┐
  │ PunctuationServer│ │  Anthropic  │  │   StringTransform │
  │ (.app / Python) │ │  Client     │  │   (Hans↔Hant)     │
  │ BERT model      │ │  (greyed    │  │                    │
  │ localhost:18230  │ │   out)      │  │                    │
  └─────────────────┘ └─────────────┘  └──────────────────┘
```

### Data Flow

```
Mic → AVAudioEngine → AVAudioConverter (16kHz mono) ─┬─→ Whisper inference → text
                                                      └─→ Apple Speech buffer → text
                                                                │
                                                                ▼
                                              Punctuation Restore (optional, BERT)
                                                                │
                                                                ▼
                                              Script Conversion (Hans ↔ Hant)
                                                                │
                                                                ▼
                                                         Display / Copy
```

## STT Engines

| Engine | Requires | Mode | Best For |
|--------|----------|------|----------|
| Whisper | Downloaded model | Batch (record then transcribe) | Offline use, accuracy |
| Apple Speech | Network connection | Streaming (real-time) | Quick dictation, live preview |

Both engines support mixed Chinese + English speech.

## Available Whisper Models

| Model | Size | Quality |
|-------|------|---------|
| Tiny | ~75 MB | Fastest, lowest quality |
| Base | ~142 MB | Good balance |
| Small | ~466 MB | Better accuracy |
| Medium | ~1.5 GB | High accuracy |
| Large v3 Turbo | ~1.6 GB | Best accuracy |

Models are downloaded from HuggingFace to `~/Library/Application Support/Voice2Text/`.

## Punctuation Server (Optional)

A standalone BERT-based server that adds punctuation to raw STT output (Chinese). Uses the [p208p2002/zh-wiki-punctuation-restore](https://huggingface.co/p208p2002/zh-wiki-punctuation-restore) model.

### Run from source

```bash
cd scripts
pip install -r requirements.txt
python punctuation_server.py
```

### Build standalone .app

```bash
cd scripts
bash build_app.sh
# Output: dist/PunctuationServer.app
```

The server listens on `http://127.0.0.1:18230`:
- `GET /health` — health check
- `POST /restore` — `{"text": "..."}` → `{"text": "punctuated...", "elapsed_ms": 42}`

Voice2Text auto-launches the server app if found in `/Applications/`, `~/Applications/`, or alongside the Voice2Text.app bundle.

## Project Structure

```
Voice2Text/
├── Voice2TextApp.swift          # @main entry point, MenuBarExtra + Window scene
├── AppState.swift               # Shared state, transcription pipeline, model management
├── MenuBarView.swift            # Menu bar dropdown UI
├── ContentView.swift            # Main window: model picker, transcription editor, controls
├── AudioRecorder.swift          # AVAudioEngine + AVAudioConverter (16kHz mono Float32)
├── WhisperBridge.swift          # Swift wrapper around whisper.cpp C API
├── AppleSpeechRecognizer.swift  # Apple SFSpeechRecognizer wrapper
├── PunctuationClient.swift      # HTTP client + auto-launcher for punctuation server
├── AnthropicClient.swift        # Claude API client (feature greyed out)
├── AppDelegate.swift            # Dock icon handler
├── WindowAccessor.swift         # NSWindow reference capture + hide-on-close
├── Voice2Text-Bridging-Header.h # C interop header for whisper.cpp
├── Voice2Text.entitlements      # App Sandbox: audio-input + network-client
├── Info.plist                   # Microphone + Speech Recognition usage descriptions
└── Assets.xcassets/             # Asset catalog
Whisper/
├── lib/                         # Pre-built static libraries (whisper, ggml, metal, cpu, blas)
└── include/                     # Header files (whisper.h, ggml*.h)
scripts/
├── punctuation_server.py        # Chinese punctuation restoration server
├── PunctuationServer.spec       # PyInstaller spec for building .app
├── build_app.sh                 # Build script for PunctuationServer.app
└── requirements.txt             # Python dependencies
project.yml                      # XcodeGen spec
```

## Known Issues

- **Dock icon click does not reopen main window** — use "Open Window" from menu bar dropdown as workaround

## TODO

- [ ] Fix Dock icon reopen window
- [ ] WAV export for batch processing
- [ ] Global keyboard shortcut for start/stop
- [ ] UI redesign: separate settings from main workflow
- [ ] LLM text reformatting (blocked by company proxy)

## License

This project is available under the **MIT License**.

### Third-Party Licenses

| Dependency | License |
|-----------|---------|
| [whisper.cpp](https://github.com/ggerganov/whisper.cpp) | MIT |
| [XcodeGen](https://github.com/yonaskolb/XcodeGen) | MIT |
| [PyTorch](https://github.com/pytorch/pytorch) | BSD |
| [Hugging Face Transformers](https://github.com/huggingface/transformers) | Apache 2.0 |
| [PyInstaller](https://github.com/pyinstaller/pyinstaller) | GPL 2.0 (with bootloader exception) |
| [zh-wiki-punctuation-restore](https://huggingface.co/p208p2002/zh-wiki-punctuation-restore) | Unspecified |
| Apple Frameworks (SwiftUI, AVFoundation, Speech) | Proprietary (Apple SDK) |
