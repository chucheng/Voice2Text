# Voice2Text — 100% Local Voice Input for macOS

**Free, open-source voice-to-text for macOS — everything runs locally on your Mac, no cloud services, no API fees, no subscription.**

Powered by OpenAI Whisper for speech recognition and Qwen LLM for intelligent post-editing — both running entirely on-device. Hold a hotkey, speak, and your words appear at the cursor in any app.

**免费、开源的 macOS 语音输入工具 — 所有功能皆在本机运行，无需云端服务、无需 API 费用、无需订阅。**

采用 OpenAI Whisper 语音识别 + Qwen LLM 智能润稿，全部在设备端执行。按住快捷键说话，文字自动出现在任何应用程序的光标位置。

---

> **Supports 99 languages via Whisper.** Optimized for Chinese + English mixed input. On-device Qwen LLM adds punctuation and polishes transcription — no internet needed. Optional Cloud API (Anthropic Claude) also available for users who prefer it.
>
> **支持 99 种语言。** 针对中英文混合输入特别优化。设备端 Qwen LLM 自动加标点、润稿 — 无需联网。也可选用云端 API（Anthropic Claude）。

---

## How It Works

1. **Hold ⌘;** from any app (browser, terminal, chat, editor...)
2. **Speak** in Chinese, English, or both
3. **Release** — text is transcribed and pasted at your cursor

That's it. No window switching, no copy-paste. Transcription powered by [whisper.cpp](https://github.com/ggerganov/whisper.cpp) and post-editing by [Qwen LLM](https://huggingface.co/Qwen) — both running entirely on your Mac, no cloud required. Optional Cloud API (Anthropic Claude) also available.

## Features

- **Global hotkey (⌘;)** — hold from any app to record, release to auto-paste at cursor
- **Dual STT engines** — whisper.cpp (offline) and Apple Speech Recognition (online, streaming)
- **99 languages supported** — Whisper auto-detects language; optimized for Chinese + English
- **In-app language switching** — English / 简体中文 UI, selectable during onboarding and in Settings
- **Simplified/Traditional Chinese** output toggle
- **Multiple whisper models** — tiny, base, small, medium, large-v3-turbo (downloaded on-demand)
- **Push-to-talk** — hold Spacebar to record in-app, release to transcribe
- **Floating indicator** — compact pill shows recording/transcribing/done status
- **Local LLM post-editing** — on-device Qwen 3.5 / 2.5 models add punctuation and polish transcription — no internet needed
- **Cloud API option** — optional Anthropic Claude integration for users who prefer cloud-based post-editing
- **Language-aware editing** — non-English: focus on adding punctuation; English: detailed grammar/spelling fixes; mixed: per-segment rules
- **Punctuation restoration** — built-in CoreML BERT model adds punctuation for Chinese text (fallback when no LLM active)
- **Customizable shortcut** — change the global hotkey in Settings
- **Editable transcription** — edit text inline after transcription
- **Cmd+C smart copy** — copies full transcription when nothing selected
- **Custom Revise Prompt** — customize what the LLM does with your transcript
- **Secure API Key storage** — API Key stored in macOS Keychain, never in plaintext
- **What's New screen** — shows changes after version update, auto-dismisses in 8 seconds
- **Debug log window** — separate resizable window with Copy All for troubleshooting
- **Dev mode** — always-on logging (capped at 500 lines), viewable in debug log window
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

> **Note:** `.xcodeproj` is not checked into git — it's generated from `project.yml` by XcodeGen.

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
  ┌─────────────────┐ ┌─────────────┐ ┌─────────────┐ ┌──────────────────┐
  │  Punctuation    │ │  Local LLM  │ │  Anthropic  │ │   StringTransform │
  │  Restorer       │ │  (Qwen 3.5/ │ │  Client     │ │   (Hans↔Hant)     │
  │  (CoreML BERT)  │ │  on-device) │ │ (Cloud API) │ │                    │
  │  in-process     │ │             │ │             │ │                    │
  └─────────────────┘ └─────────────┘ └─────────────┘ └──────────────────┘
```

### Data Flow

```
Mic → AVAudioEngine → AVAudioConverter (16kHz mono) ─┬─→ Whisper inference → text
                                                      └─→ Apple Speech buffer → text
                                                                │
                                                                ▼
                                              Punctuation Restore (fallback, CoreML BERT, Chinese only)
                                                                │
                                                                ▼
                                              Post-Edit (Local Qwen LLM or Cloud Claude API)
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

The only difference: punctuation restoration (CoreML BERT model) is Chinese-only. For non-Chinese speech, it is automatically skipped — your text will be transcribed without auto-punctuation, but everything else works.

### What works automatically

- **Any Whisper-supported language** — transcription via `language="auto"`
- **Punctuation auto-skip** — the Chinese BERT model is only used when Chinese text is detected
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

The built-in punctuation model uses a Chinese-specific BERT model converted to CoreML. To add punctuation for your language:
- Convert a suitable BERT token classification model using `scripts/convert_punctuation_model.py` as a template
- Update the label mapping in `PunctuationRestorer.swift`

Pull requests for multi-language improvements are welcome.

## Available Whisper Models

| Model | Size | Quality |
|-------|------|---------|
| Tiny | ~75 MB | Fastest, lowest quality |
| Base | ~142 MB | Good balance |
| Small | ~466 MB | Better accuracy |
| Medium | ~1.5 GB | High accuracy |
| Large v3 Turbo | ~1.6 GB | Best accuracy |

Models are downloaded from [ggerganov/whisper.cpp on HuggingFace](https://huggingface.co/ggerganov/whisper.cpp) to `~/Library/Application Support/Voice2Text/`.

## Available Qwen LLM Models (Optional)

On-device post-editing uses [Qwen](https://huggingface.co/Qwen) models in GGUF format, powered by [llama.cpp](https://github.com/ggerganov/llama.cpp). Select and download from Settings > AI Services > Local LLM.

### Qwen 3.5 (Recommended)

| Model | Size | Quality | Recommendation |
|-------|------|---------|----------------|
| Qwen 3.5 0.8B | ~500 MB | Good punctuation | Low-end Macs |
| Qwen 3.5 2B | ~1.3 GB | Great balance | **Recommended for most users** |
| Qwen 3.5 4B | ~2.5 GB | Excellent quality | 16 GB+ RAM |

Qwen 3.5 is the latest generation with improved instruction-following and multilingual performance. `/no_think` is automatically prepended to disable reasoning mode for clean output.

### Qwen 2.5 (Legacy)

| Model | Size | Quality | Recommendation |
|-------|------|---------|----------------|
| Qwen 2.5 0.5B | ~400 MB | Basic punctuation | Low-end Macs |
| Qwen 2.5 1.5B | ~1.0 GB | Good balance | General use |
| Qwen 2.5 3B | ~2.0 GB | Better grammar fixes | 16 GB+ RAM |
| Qwen 2.5 7B | ~3.5 GB | Best quality | 32 GB+ RAM |

Models run entirely on-device with Metal GPU acceleration. Larger models produce better results but require more RAM and take longer to load.

## Punctuation Restoration (Optional)

Built-in CoreML BERT model that adds punctuation to raw STT output (Chinese only). Uses the [p208p2002/zh-wiki-punctuation-restore](https://huggingface.co/p208p2002/zh-wiki-punctuation-restore) model converted to CoreML format.

- **No external server needed** — inference runs in-process via CoreML
- **Download from Settings** — Settings > Advanced > Download Punctuation Model (~179 MB)
- **Auto-enabled** — once downloaded, punctuation restore is enabled by default
- **Chinese only** — automatically skipped for non-Chinese text

### Model Conversion (Developer)

To regenerate the CoreML model from the PyTorch source:

```bash
pip install torch transformers coremltools
python scripts/convert_punctuation_model.py
# Output: scripts/zh-punctuation-bert.mlpackage.zip
```

Upload the zip to GitHub Releases for in-app download.

## Project Structure

```
Voice2Text/
├── Voice2TextApp.swift          # @main entry point, MenuBarExtra + Window scene
├── AppState.swift               # Shared state, transcription pipeline, model management, global hotkey
├── MenuBarView.swift            # Menu bar dropdown UI
├── ContentView.swift            # Main window: record button, transcription editor, permission alerts
├── OnboardingView.swift         # First-launch setup wizard (model selection + permissions)
├── SettingsView.swift           # Settings: General, Models, Shortcuts, Advanced, AI Services
├── GlobalHotkeyManager.swift    # Carbon hotkey registration, accessibility, auto-paste
├── FloatingRecordingPanel.swift # Non-activating floating panel for global hotkey feedback
├── HotkeyRecorderView.swift     # Custom shortcut recorder UI component
├── RecordButton.swift           # Animated record button with pulse/spin states
├── WaveformView.swift           # Canvas-based animated audio waveform
├── TranscriptionView.swift      # Editable transcription text area
├── CopyButton.swift             # Copy-to-clipboard button with animation
├── Strings.swift                # UILanguage enum + L localization enum (English / 简体中文)
├── AudioRecorder.swift          # AVAudioEngine + AVAudioConverter (16kHz mono Float32)
├── WhisperBridge.swift          # Swift wrapper around whisper.cpp C API
├── AppleSpeechRecognizer.swift  # Apple SFSpeechRecognizer wrapper
├── WordPieceTokenizer.swift      # WordPiece tokenizer for BERT (loads vocab.txt from bundle)
├── PunctuationRestorer.swift    # CoreML BERT inference for Chinese punctuation restoration
├── vocab.txt                    # WordPiece vocabulary (21K tokens) bundled for tokenizer
├── AnthropicClient.swift        # Claude API client: API check, Post-Edit Revise, custom prompt
├── LlamaBridge.swift            # Swift wrapper around llama.cpp C API for local LLM inference
├── WhatsNewView.swift           # What's New overlay with 8s countdown auto-dismiss
├── WhatsNew.json                # Bundled changelog (bilingual en/zh)
├── DebugLogWindow.swift         # Separate debug log window with Copy All
├── KeychainHelper.swift         # macOS Keychain wrapper for API token storage
├── AppDelegate.swift            # Dock icon handler + graceful shutdown
├── WindowAccessor.swift         # NSWindow reference capture + quit-on-close
├── Voice2Text-Bridging-Header.h # C interop header for whisper.cpp + llama.cpp
├── Voice2Text.entitlements      # App Sandbox: audio-input + network-client
├── Info.plist                   # Microphone + Speech Recognition usage descriptions
└── Assets.xcassets/             # Asset catalog
Whisper/
├── lib/                         # Pre-built static libraries (whisper, ggml, metal, cpu, blas)
└── include/                     # Header files (whisper.h, ggml*.h)
LlamaCpp/
├── lib/                         # Pre-built static library (libllama.a)
└── include/                     # Header file (llama.h)
docs/
├── Getting Started.html         # User guide included in DMG
└── images/                      # Screenshots for the guide
scripts/
├── convert_punctuation_model.py # Convert PyTorch BERT → CoreML .mlpackage
├── build_dmg.sh                 # Build Voice2Text.dmg for distribution
├── build_llama.sh               # Build llama.cpp static lib for macOS arm64
├── build_whisper.sh             # Build whisper.cpp static lib for macOS arm64
└── requirements.txt             # Python dependencies for model conversion
project.yml                      # XcodeGen spec
```

## Release Notes

### v2.2.0

- New: Qwen 3.5 model support (0.8B / 2B / 4B) — latest generation on-device LLM with improved post-editing quality
- New: `/no_think` auto-prepended for Qwen 3.5 to disable reasoning mode and output clean text
- New: `<think>` tag stripping as safety net for Qwen 3.5 output
- Changed: Default recommended model updated from Qwen 2.5 1.5B to Qwen 3.5 2B

### v2.1.1

- Docs: Update Getting Started guide — add Local LLM option to AI post-edit section, fix bilingual tab names in Settings table, update version to 2.1.1

### v2.1.0

- New: Tap AI service badge (Local LLM / AI Revise) to pause/resume post-editing — model stays loaded for instant resume

### v2.0.2

- Gitignore `.pbxproj` (generated by xcodegen)

### v2.0.1

- Fix: CJK characters no longer corrupted in Local LLM output (multi-byte UTF-8 split across tokens)

### v2.0.0 — What's New Since 1.0

**On-Device AI Post-Editing**
- Local LLM inference via [llama.cpp](https://github.com/ggerganov/llama.cpp) — Qwen 3.5 / 2.5 models run entirely on your Mac
- Language-aware editing: adds punctuation for Chinese, fixes grammar for English
- Built-in CoreML BERT punctuation restoration as fallback (no external server)
- Optional Cloud API (Anthropic Claude) for users who prefer it
- Custom revise prompt support

**Global Hotkey**
- Hold ⌘; from any app → record → release → transcription auto-pasted at cursor
- Floating recording panel (non-activating, doesn't steal focus)
- Customizable shortcut, 30-second clipboard auto-clear

**99 Languages**
- Whisper `language="auto"` detects any of 99 supported languages
- Optimized for Chinese + English mixed speech with auto-retry logic

**Bilingual UI**
- English / 简体中文 — switchable in Settings or during onboarding
- ~120 localized strings

**Polish**
- Three-state status badges (tap to activate/retry)
- Setup wizard with model download + accessibility guidance
- What's New screen on version update
- Debug log window with full input/output in dev mode
- Download protection with cancel, corrupt model auto-detection
- Lazy Keychain access (never read during app launch)

## License

This project is licensed under the **GNU General Public License v3.0** — see the [LICENSE](LICENSE) file for details.

### Third-Party Licenses

Full license texts are available in [THIRD-PARTY-NOTICES](THIRD-PARTY-NOTICES).

| Dependency | License | Bundled? |
|-----------|---------|----------|
| [whisper.cpp](https://github.com/ggerganov/whisper.cpp) | MIT | Yes (static lib) |
| [llama.cpp](https://github.com/ggerganov/llama.cpp) | MIT | Yes (static lib) |
| [OpenAI Whisper models](https://github.com/openai/whisper) | MIT | Downloaded at runtime |
| [Qwen 3.5 / 2.5 models](https://huggingface.co/Qwen) | Apache 2.0 | Downloaded at runtime (GGUF, opt-in) |
| [zh-wiki-punctuation-restore](https://huggingface.co/p208p2002/zh-wiki-punctuation-restore) | Not specified | Downloaded at runtime (CoreML, Chinese only, opt-in) |
| [XcodeGen](https://github.com/yonaskolb/XcodeGen) | MIT | Build tool only |
| Apple Frameworks (SwiftUI, AVFoundation, Speech, Carbon, CoreML) | Apple SDK | OS-provided |
