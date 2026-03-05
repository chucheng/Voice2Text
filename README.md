# Voice2Text — 100% Local Voice Input for macOS

**Free, open-source voice-to-text for macOS — everything runs locally on your Mac, no cloud services, no API fees, no subscription.**

Powered by OpenAI Whisper for speech recognition and Qwen LLM for intelligent post-editing — both running entirely on-device. Hold a hotkey, speak, and your words appear at the cursor in any app.

**免費、開源的 macOS 語音輸入工具 — 所有功能皆在本機運行，無需雲端服務、無需 API 費用、無需訂閱。**

採用 OpenAI Whisper 語音辨識 + Qwen LLM 智慧潤稿，全部在設備端執行。按住快捷鍵說話，文字自動出現在任何應用程式的游標位置。

---

> **Supports 99 languages via Whisper.** Optimized for Chinese + English mixed input. On-device Qwen LLM adds punctuation and polishes transcription — no internet needed. Optional Cloud API (Anthropic Claude) also available for users who prefer it.
>
> **支援 99 種語言。** 針對中英文混合輸入特別優化。設備端 Qwen LLM 自動加標點、潤稿 — 無需聯網。也可選用雲端 API（Anthropic Claude）。

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
- **Local LLM post-editing** — on-device Qwen 2.5 models (0.5B/1.5B/3B/7B) add punctuation and polish transcription — no internet needed
- **Cloud API option** — optional Anthropic Claude integration for users who prefer cloud-based post-editing
- **Language-aware editing** — non-English: focus on adding punctuation; English: detailed grammar/spelling fixes; mixed: per-segment rules
- **Punctuation restoration** — built-in CoreML BERT model adds punctuation for Chinese text (fallback when no LLM active)
- **Customizable shortcut** — change the global hotkey in Settings
- **Editable transcription** — edit text inline after transcription
- **Cmd+C smart copy** — copies full transcription when nothing selected
- **Custom Revise Prompt** — customize what the LLM does with your transcript
- **Secure API Key storage** — API Key stored in macOS Keychain, never in plaintext
- **What's New screen** — shows changes after version update, auto-dismisses in 3 seconds
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
  │  Restorer       │ │  (Qwen 2.5  │ │  Client     │ │   (Hans↔Hant)     │
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
├── WhatsNewView.swift           # What's New overlay with 3s countdown auto-dismiss
├── WhatsNew.json                # Bundled changelog (bilingual en/zh)
├── DebugLogWindow.swift         # Separate debug log window with Copy All
├── KeychainHelper.swift         # macOS Keychain wrapper for API token storage
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
├── convert_punctuation_model.py # Convert PyTorch BERT → CoreML .mlpackage
├── build_dmg.sh                 # Build Voice2Text.dmg for distribution
└── requirements.txt             # Python dependencies for model conversion
project.yml                      # XcodeGen spec
```

## Release Notes

### v1.9.1 — Language-Aware Prompt + AI Service Badge
- **Language-aware prompt** — non-English: focus on adding punctuation; English: detailed grammar/spelling/tense fixes; mixed: applies appropriate rules per segment
- **AI service badge** — main window shows active provider status (Local LLM orange/red, AI Revise green/red)
- **BERT auto-disable** — punctuation toggle disabled when any LLM provider is active (not just Cloud API)

### v1.9.0 — Post-Edit Provider + Local LLM Model Selection
- **Post-Edit Provider picker** — choose None, Local LLM (offline), or Cloud API (Anthropic Claude) in Settings > AI Services
- **Local LLM model selection** — Qwen 2.5 models (0.5B/1.5B/3B/7B) with on-demand download, recommended model guidance
- **Download prompt** — new users see a guided flow to download the recommended 1.5B model
- **Credential fix** — Base URL and Model fields use explicit Save/Revert buttons (no more per-keystroke auto-save)
- **Provider switching** — correctly preserves Cloud API validation state when switching between providers

### v1.8.4 — AI Services Credential Fix
- **Fix** — Base URL and Model fields no longer auto-save on every keystroke; explicit Save Credentials / Revert buttons added
- **Safer editing** — accidental edits are not persisted until you click Save; Check API disabled while unsaved changes exist

### v1.8.3 — Floating Panel Fix
- **Fix** — floating recording panel now repositions to top-center of current screen on every hotkey press (handles screen/resolution changes)

### v1.8.1 — UI Polish + Auto API Check
- **User-friendly capsules** — renamed BERT → Auto-Punct, LLM → AI Revise in top bar
- **Smart capsule visibility** — Auto-Punct capsule hidden when AI Revise is active (avoids confusion)
- **Auto API check** — enabling AI Revise now auto-triggers API credential check
- **Bug fix** — credential changes correctly cancel pending auto-enable

### v1.8.2 — Version Display
- **Version in toolbar** — app version now shown in bottom toolbar copyright text

### v1.8.0 — Built-in CoreML Punctuation (No External Server)
- **In-process BERT** — punctuation restoration runs natively via CoreML, no external PunctuationServer.app needed
- **Smaller download** — ~179 MB CoreML model vs ~500 MB PyInstaller server
- **Download/delete from Settings** — Settings > Advanced to manage the punctuation model
- **Auto-migration** — legacy PunctuationServer.app in Application Support is automatically removed
- **BERT & LLM status indicators** — status capsules in main window top bar

### v1.7.0 — In-App Punctuation Server Install + Service Status + AI Services Tab
- **One-click install** — install PunctuationServer.app directly from Settings > Advanced (~500 MB download)
- **Service status indicators** — BERT and LLM status capsules in the main window top bar
- **AI Services tab** — renamed "Dangerous Zone" to "AI Services" with cloud icon

### v1.6.2 — ATS Exception + Copyright Fix
- **ATS exception** — allow HTTP for `sheincorp.cn` domain (internal proxy support)
- **Copyright fix** — corrected to GPL v3.0 license, author C. C. Hsieh, year 2025-2026

### v1.6.1 — UI Label Update
- **API Key label** — renamed AUTH_TOKEN to API_KEY in Settings > Dangerous Zone

### v1.6.0 — Custom Revise Prompt + What's New + Debug Log Window
- **Custom Revise Prompt** — customize the LLM prompt in Settings > Dangerous Zone; Reset to Default button
- **LLM/BERT mutual exclusivity** — when Post-Edit Revise is enabled, BERT punctuation is skipped (LLM handles it). On LLM failure, falls back to BERT if available
- **What's New screen** — shown once after version update, 3-second countdown auto-dismiss, reads from bundled WhatsNew.json
- **Debug log window** — separate resizable window with Copy All button; logs always collected (500 line cap)
- **Resizable Settings window** — Settings window can now be resized
- **Updated default revise prompt** — focused on transcript correction (error fixing, punctuation, minimal rewrites)

### v1.5.0 — HTTP URL Support + UI Polish
- Allow HTTP URLs for internal proxies
- Improved Dangerous Zone tab labels

### v1.4.0 — Dangerous Zone + Post-Edit Revise
- **Post-Edit Revise** — optional Claude API integration that improves transcription clarity and flow after STT
- **Dangerous Zone tab** — new Settings tab for configuring Anthropic API credentials (base URL, model, token)
- **Keychain token storage** — API token stored securely in macOS Keychain, never in UserDefaults or logs
- **API check** — validate credentials with latency measurement before enabling revise
- **Graceful fallback** — on revise failure, falls back to original text with transient orange banner (4s)
- **State machine** — API check state (Unchecked → Checking → Valid/Invalid), auto-resets on credential changes

### v1.3.0 — In-App Language Switching
- **UI language switching** — English / 简体中文, with segmented picker on onboarding welcome step and Settings > General
- **Localized strings** — ~85 UI strings across all views, powered by `Strings.swift` `L` enum
- **System language detection** — defaults to Chinese if macOS locale contains "zh", otherwise English
- **Copyright notice** — "© C. C. Hsieh" appears in ContentView bottom toolbar after first-use tooltip disappears

### v1.2.0 — 99 Language Support
- **99 languages** — Whisper auto-detects language; all languages work out of the box
- **Smart punctuation skip** — Chinese BERT model auto-skipped for non-Chinese speech
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
- Punctuation restoration (BERT model)
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
| [zh-wiki-punctuation-restore](https://huggingface.co/p208p2002/zh-wiki-punctuation-restore) | Not specified | Downloaded at runtime (CoreML, Chinese only, opt-in) |
| [XcodeGen](https://github.com/yonaskolb/XcodeGen) | MIT | Build tool only |
| Apple Frameworks (SwiftUI, AVFoundation, Speech, Carbon, CoreML) | Apple SDK | OS-provided |
