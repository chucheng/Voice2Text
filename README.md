# Voice2Text

A macOS menu bar app for voice-to-text transcription using whisper.cpp and Apple Speech Recognition, built with SwiftUI and AVAudioEngine.

## Features

- **Dual STT engines** — whisper.cpp (offline) and Apple Speech Recognition (online, streaming)
- **Mixed Chinese + English** speech recognition
- **Simplified/Traditional Chinese** output toggle via Foundation StringTransform
- **Multiple whisper models** — tiny, base, small, medium, large-v3-turbo (downloaded on-demand)
- **Auto language retry** — detects wrong language output and retries with Chinese
- **Push-to-talk** — hold Spacebar to record, release to transcribe
- **Global hotkey (⌘;)** — hold from any app to record, release to auto-paste transcription at cursor
- **Floating indicator** — compact pill-shaped panel shows recording/transcribing/done status
- **Punctuation restoration** — BERT-based server adds punctuation automatically (enabled by default when server available)
- **Editable transcription** — edit text inline after transcription
- **Cmd+C smart copy** — copies full transcription when nothing selected, or copies selection
- **Dev mode** — debug log panel for troubleshooting
- Custom app icon
- Menu bar + Dock presence

## Installation (Non-Developer)

1. Download `Voice2Text.dmg` from the [Releases](../../releases) page
2. Open the DMG and drag **Voice2Text** to the **Applications** folder
3. Eject the DMG
4. Open **Voice2Text** from Applications — on first launch, macOS may block it:
   - Right-click (or Control-click) the app → **Open** → click **Open** in the dialog
   - This is only needed once; subsequent launches work normally
5. The **Setup Wizard** will guide you:
   - **Choose a model** — select a Whisper model to download for offline transcription, then click **Download & Continue**
   - **Or skip** — click **Skip — Use Apple Speech** to use Apple's built-in speech recognition (requires internet)
   - **Permissions** — grant Accessibility permission to enable global hotkey auto-paste (optional, can be done later in Settings)
6. After setup:
   - In-app: hold **Space** to record and release to transcribe
   - From any app: hold **⌘;** to record, release to transcribe and auto-paste at cursor

## Prerequisites (Developer)

- macOS 14+ (Sonoma)
- Xcode 15+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) — `brew install xcodegen`

## Getting Started (Developer)

```bash
# Generate the Xcode project
xcodegen generate

# Open in Xcode
open Voice2Text.xcodeproj

# Build & Run: Cmd+R in Xcode
```

On first launch, select a whisper model and click "Download". Models are saved to `~/Library/Application Support/Voice2Text/`.

## Building a DMG

To build a distributable DMG (no Apple Developer account needed):

```bash
bash scripts/build_dmg.sh
# Output: build/Voice2Text.dmg
```

This will regenerate the Xcode project, build a Release archive, ad-hoc sign it, and package it into a DMG with an Applications symlink.

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
├── AppState.swift               # Shared state, transcription pipeline, model management, global hotkey
├── MenuBarView.swift            # Menu bar dropdown UI
├── ContentView.swift            # Main window: record button, transcription editor, permission alerts
├── OnboardingView.swift         # First-launch setup wizard (model selection + permissions)
├── SettingsView.swift           # Settings: General, Models, Shortcuts, Advanced
├── GlobalHotkeyManager.swift    # Carbon hotkey registration, accessibility, auto-paste
├── FloatingRecordingPanel.swift # Non-activating floating panel for global hotkey feedback
├── HotkeyRecorderView.swift     # Custom shortcut recorder UI component
├── RecordButton.swift           # Animated record button with pulse/spin states
├── WaveformView.swift           # Canvas-based animated audio waveform
├── TranscriptionView.swift      # Editable transcription text area
├── CopyButton.swift             # Copy-to-clipboard button with animation
├── AudioRecorder.swift          # AVAudioEngine + AVAudioConverter (16kHz mono Float32)
├── WhisperBridge.swift          # Swift wrapper around whisper.cpp C API
├── AppleSpeechRecognizer.swift  # Apple SFSpeechRecognizer wrapper
├── PunctuationClient.swift      # HTTP client + auto-launcher for punctuation server
├── AnthropicClient.swift        # Claude API client (feature greyed out)
├── AppDelegate.swift            # Dock icon handler + graceful shutdown
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
├── build_dmg.sh                 # Build Voice2Text.dmg for distribution
└── requirements.txt             # Python dependencies
project.yml                      # XcodeGen spec
```

## Release Notes

### v1.1.1 — Bug Fixes & Polish
- **Launch permission checks** — proactively prompts for Microphone and Accessibility on startup
- **"Disable Global Hotkey" option** — users who don't want auto-paste can disable to suppress Accessibility prompts
- **Fix quit crash** — thread-safe whisper model cleanup (`freeModelSync` on inference queue)
- **Fix terminate race** — stop audio engine directly on quit instead of triggering async transcription
- **Fix accessibility polling** — stops when permission is granted instead of running indefinitely
- **Fix hotkey recorder leak** — event monitor cleaned up on view disappear
- **Code cleanup** — removed dead code, unused imports, duplicate WindowAccessor

### v1.1.0 — Global Push-to-Talk Hotkey
- **Global hotkey (⌘;)** — hold from any app to record, release to transcribe and auto-paste at cursor
- **Floating recording panel** — non-intrusive indicator shows recording/transcribing/done status
- **Auto-paste** — transcription is copied to clipboard and pasted via simulated ⌘V (requires Accessibility permission)
- **Customizable shortcut** — change the hotkey in Settings > Shortcuts
- **Onboarding: permissions step** — guides new users through Accessibility setup with clear explanation
- **Onboarding: upgrade detection** — detects existing downloaded models, shows "Downloaded" badge, no re-download needed
- **Settings: Shortcuts tab** — enable/disable global hotkey, record custom shortcut, Accessibility status
- **Graceful quit** — fixed SIGABRT crash on quit by properly cleaning up Carbon hotkey and whisper model before exit

### v1.0.0 — Initial Release
- Dual STT engines (whisper.cpp offline + Apple Speech online)
- Mixed Chinese + English recognition
- Simplified/Traditional Chinese output toggle
- Push-to-talk (Spacebar) in-app recording
- Punctuation restoration (BERT server)
- Multiple whisper models (tiny → large-v3-turbo)
- Menu bar + Dock presence
- First-launch setup wizard

## Known Issues

- **Dock icon click does not reopen main window** — use "Open Window" from menu bar dropdown as workaround

## TODO

- [ ] WAV export for batch processing
- [ ] UI redesign: separate settings from main workflow
- [ ] LLM text reformatting (blocked by company proxy)
- [ ] Model checksum (SHA-256) verification

## License

This project is licensed under the **GNU General Public License v3.0** — see the [LICENSE](LICENSE) file for details.

### Third-Party Licenses

Full license texts are available in [THIRD-PARTY-NOTICES](THIRD-PARTY-NOTICES).

| Dependency | License | Bundled? |
|-----------|---------|----------|
| [whisper.cpp](https://github.com/ggerganov/whisper.cpp) | MIT | Yes (static lib) |
| [OpenAI Whisper models](https://github.com/openai/whisper) | MIT | Downloaded at runtime |
| [PyTorch](https://github.com/pytorch/pytorch) | BSD 3-Clause | In PunctuationServer.app |
| [Hugging Face Transformers](https://github.com/huggingface/transformers) | Apache 2.0 | In PunctuationServer.app |
| [PyInstaller](https://github.com/pyinstaller/pyinstaller) | GPL 2.0 (bootloader exception) | Bootloader only |
| [zh-wiki-punctuation-restore](https://huggingface.co/p208p2002/zh-wiki-punctuation-restore) | Not specified | Downloaded at runtime |
| [XcodeGen](https://github.com/yonaskolb/XcodeGen) | MIT | Build tool only |
| Apple Frameworks (SwiftUI, AVFoundation, Speech, Carbon) | Apple SDK | OS-provided |
