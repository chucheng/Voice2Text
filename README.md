# Voice2Text — Open-Source Whisper Voice Input for macOS

**Free, open-source, offline voice-to-text for macOS.** Hold a hotkey, speak, and your words appear at the cursor — in any app.

**免費、開源、離線語音輸入工具。** 按住快捷鍵說話，文字自動出現在游標位置 — 在任何應用程式中都能使用。

---

> **Supports 99 languages via Whisper.** Optimized for Chinese + English mixed input with automatic punctuation restoration. Other languages work out of the box — just speak and Whisper auto-detects.
>
> **支援 99 種語言。** 針對中英文混合輸入特別優化，含自動標點還原。其他語言開箱即用 — 直接說話，Whisper 會自動辨識語言。

---

## How It Works

1. **Hold ⌘;** from any app (browser, terminal, chat, editor...)
2. **Speak** in Chinese, English, or both
3. **Release** — text is transcribed and pasted at your cursor

That's it. No window switching, no copy-paste. Powered by [whisper.cpp](https://github.com/ggerganov/whisper.cpp) running entirely on your Mac — no cloud, no API keys, no subscription.

## Features

- **Global hotkey (⌘;)** — hold from any app to record, release to auto-paste at cursor
- **Dual STT engines** — whisper.cpp (offline) and Apple Speech Recognition (online, streaming)
- **99 languages supported** — Whisper auto-detects language; optimized for Chinese + English
- **Simplified/Traditional Chinese** output toggle
- **Multiple whisper models** — tiny, base, small, medium, large-v3-turbo (downloaded on-demand)
- **Push-to-talk** — hold Spacebar to record in-app, release to transcribe
- **Floating indicator** — compact pill shows recording/transcribing/done status
- **Punctuation restoration** — optional BERT server adds punctuation for Chinese text (auto-skipped for other languages)
- **Customizable shortcut** — change the global hotkey in Settings
- **Editable transcription** — edit text inline after transcription
- **Cmd+C smart copy** — copies full transcription when nothing selected
- **Dev mode** — debug log panel for troubleshooting
- Menu bar + Dock presence

## Installation (Non-Developer)

1. Download `Voice2Text.dmg` from the [Releases](../../releases) page
2. Open the DMG and drag **Voice2Text** to the **Applications** folder
3. Eject the DMG
4. Open **Voice2Text** from Applications — on first launch, macOS will show a security warning ("cannot verify"):
   - Right-click (or Control-click) the app → **Open** → click **Open** in the dialog
   - Or run in Terminal: `xattr -cr /Applications/Voice2Text.app`
   - This is only needed once; subsequent launches work normally
   - *(This happens because the app is ad-hoc signed without an Apple Developer certificate)*
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

Both engines currently support mixed Chinese + English speech.

## Adding Other Languages

Whisper supports [99 languages](https://github.com/openai/whisper#available-models-and-languages). **Voice2Text already works with all of them out of the box** — just speak in any language and Whisper's `language="auto"` will detect it.

The only difference: punctuation restoration (BERT server) is Chinese-only. For non-Chinese speech, it is automatically skipped — your text will be transcribed without auto-punctuation, but everything else works.

### What works automatically

- **Any Whisper-supported language** — transcription via `language="auto"`
- **Punctuation auto-skip** — the Chinese BERT server is only used when Chinese text is detected
- **Chinese + English mixed speech** — fully optimized with retry logic and punctuation restore

### Optional: Fine-tune for a specific language

If you want to optimize for a specific non-Chinese language:

#### Change Apple Speech locale (optional)

In `AppleSpeechRecognizer.swift`, the recognizer is initialized with `zh-Hant` (Traditional Chinese):

```swift
private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh-Hant"))
```

Change this to your target locale (e.g., `"ja-JP"`, `"ko-KR"`, `"es-ES"`). You can also make this configurable via the UI.

#### Remove script conversion (optional)

The `convertScript()` method in `AppState.swift` converts between Simplified and Traditional Chinese. For non-Chinese languages, you can simply remove this step or replace it with your own post-processing.

#### Add a punctuation model for your language (optional)

The bundled punctuation server uses a Chinese-specific BERT model. To add punctuation for your language:
- Replace the model in `scripts/punctuation_server.py` with one that supports your language
- Or use a different punctuation restoration service

Pull requests for multi-language improvements are welcome.

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

### v1.2.0 — 99 Language Support
- **99 languages** — Whisper auto-detects language; all languages work out of the box
- **Smart punctuation skip** — Chinese BERT server auto-skipped for non-Chinese speech
- **Upgrade permission detection** — detects invalidated Accessibility after app upgrade, guides user to remove and re-add
- **Microphone check on first launch** — prompts immediately after onboarding completes
- **Default Simplified Chinese** — output script defaults to Simplified (persisted across launches)
- **UI clarity** — Punctuation option labeled "Chinese + English only" with license note

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
| [zh-wiki-punctuation-restore](https://huggingface.co/p208p2002/zh-wiki-punctuation-restore) | Not specified | Downloaded at runtime (Chinese only, opt-in) |
| [XcodeGen](https://github.com/yonaskolb/XcodeGen) | MIT | Build tool only |
| Apple Frameworks (SwiftUI, AVFoundation, Speech, Carbon) | Apple SDK | OS-provided |
