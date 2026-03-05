import Foundation

// MARK: - UILanguage

enum UILanguage: String, CaseIterable, Identifiable {
    case english = "English"
    case chinese = "简体中文"

    var id: String { rawValue }

    /// Detect system language: if locale contains "zh", default to Chinese.
    static var systemDefault: UILanguage {
        let lang = Locale.current.language.languageCode?.identifier ?? ""
        return lang.hasPrefix("zh") ? .chinese : .english
    }
}

// MARK: - L (Localized Strings)

enum L {
    private static var lang: UILanguage { AppState.shared.uiLanguage }

    // MARK: OnboardingView — Welcome

    static var welcomeTitle: String {
        lang == .english ? "Welcome to Voice2Text" : "欢迎使用 Voice2Text"
    }
    static var welcomeSubtitle: String {
        lang == .english
            ? "Transcribe speech to text using AI — right from your menu bar."
            : "利用 AI 将语音转为文字，就在菜单栏中。"
    }
    static var getStarted: String {
        lang == .english ? "Get Started" : "开始使用"
    }

    // MARK: OnboardingView — Model Selection

    static var chooseModel: String {
        lang == .english ? "Choose a Speech Model" : "选择语音模型"
    }
    static var chooseModelSubtitle: String {
        lang == .english
            ? "Download a Whisper model for offline transcription, or skip to use Apple Speech (requires internet)."
            : "下载 Whisper 模型进行离线转写，或跳过使用 Apple Speech（需联网）。"
    }
    static var skipAppleSpeech: String {
        lang == .english ? "Skip — Use Apple Speech" : "跳过 — 使用 Apple Speech"
    }
    static func continueWith(_ model: String) -> String {
        lang == .english ? "Continue with \(model)" : "继续使用 \(model)"
    }
    static var downloadAndContinue: String {
        lang == .english ? "Download & Continue" : "下载并继续"
    }
    static var downloaded: String {
        lang == .english ? "Downloaded" : "已下载"
    }

    // MARK: OnboardingView — Model Descriptions

    static func modelDescription(_ model: WhisperModel) -> String {
        switch model {
        case .tiny:
            return lang == .english ? "Fastest, lowest accuracy" : "最快速，准确度最低"
        case .base:
            return lang == .english ? "Good balance of speed and accuracy" : "速度与准确度的良好平衡"
        case .small:
            return lang == .english ? "Better accuracy, moderate size" : "更高准确度，中等大小"
        case .medium:
            return lang == .english ? "High accuracy, large download" : "高准确度，下载较大"
        case .largeTurbo:
            return lang == .english ? "Best accuracy, largest download" : "最高准确度，下载最大"
        }
    }

    // MARK: OnboardingView — Downloading

    static func downloading(_ modelName: String) -> String {
        lang == .english ? "Downloading \(modelName)" : "正在下载 \(modelName)"
    }
    static var downloadComplete: String {
        lang == .english ? "Download complete!" : "下载完成！"
    }

    // MARK: OnboardingView — Permissions

    static var globalHotkey: String {
        lang == .english ? "Global Hotkey" : "全局快捷键"
    }
    static var hotkeyDescription: String {
        lang == .english
            ? "**Hold ⌘; from any app** to start recording, **release** to transcribe and auto-paste at your cursor."
            : "在任意应用中**按住 ⌘;** 开始录音，**松开**即可转写并自动粘贴到光标处。"
    }
    static var hotkeyFeature1: String {
        lang == .english
            ? "Voice-to-text in any app — no switching windows"
            : "任何应用中语音转文字 — 无需切换窗口"
    }
    static var hotkeyFeature2: String {
        lang == .english
            ? "Hold to record, release to paste — one shortcut does it all"
            : "按住录音，松开粘贴 — 一个快捷键搞定"
    }
    static var hotkeyFeature3: String {
        lang == .english
            ? "Works in browsers, editors, chat apps, terminals..."
            : "适用于浏览器、编辑器、聊天应用、终端等…"
    }
    static var accessibilityNote: String {
        lang == .english
            ? "Accessibility permission is needed so Voice2Text can paste text at your cursor position."
            : "需要辅助功能权限，Voice2Text 才能将文字粘贴到光标位置。"
    }
    static var accessibilityGranted: String {
        lang == .english ? "Accessibility Granted" : "辅助功能已授权"
    }
    static var openSystemSettings: String {
        lang == .english ? "Open System Settings" : "打开系统设置"
    }
    static var continueButton: String {
        lang == .english ? "Continue" : "继续"
    }
    static var skipForNow: String {
        lang == .english ? "Skip for Now" : "暂时跳过"
    }

    // MARK: ContentView

    static var autoPunctuation: String {
        lang == .english ? "Auto-Punct" : "自动标点"
    }
    static var aiRevise: String {
        lang == .english ? "AI Revise" : "AI 修正"
    }
    static var reformatting: String {
        lang == .english ? "Reformatting..." : "正在重新格式化…"
    }
    static var transcribing: String {
        lang == .english ? "Transcribing..." : "正在转写…"
    }
    static var starting: String {
        lang == .english ? "Starting..." : "正在启动…"
    }
    static var recording: String {
        lang == .english ? "Recording..." : "正在录音…"
    }
    static var holdSpaceToRecord: String {
        lang == .english ? "Hold Space to record" : "按住空格键录音"
    }
    static var noModelLoaded: String {
        lang == .english ? "No model loaded" : "未加载模型"
    }
    static var noNetwork: String {
        lang == .english ? "No network" : "无网络"
    }
    static var settingsTooltip: String {
        lang == .english ? "Settings (⌘,)" : "设置 (⌘,)"
    }
    static var firstUseTooltip: String {
        lang == .english ? "Hold Space to record, ⌘C to copy" : "按住空格键录音，⌘C 复制"
    }

    // MARK: ContentView — Alerts

    static var micAccessRequired: String {
        lang == .english ? "Microphone Access Required" : "需要麦克风权限"
    }
    static var micAccessMessage: String {
        lang == .english
            ? "Voice2Text needs microphone access to record audio. Please enable it in System Settings > Privacy & Security > Microphone."
            : "Voice2Text 需要麦克风权限来录制音频。请在系统设置 > 隐私与安全 > 麦克风中启用。"
    }
    static var enableAutoPaste: String {
        lang == .english ? "Enable Auto-Paste?" : "启用自动粘贴？"
    }
    static var autoPasteMessage: String {
        lang == .english
            ? "Grant Accessibility permission to let the global hotkey (⌘;) auto-paste transcriptions at your cursor. Without it, text will only be copied to clipboard."
            : "授予辅助功能权限，让全局快捷键 (⌘;) 自动将转写内容粘贴到光标处。否则，文字仅会复制到剪贴板。"
    }
    static var accessibilityNeedsRefresh: String {
        lang == .english ? "Accessibility Permission Needs Refresh" : "辅助功能权限需要刷新"
    }
    static var accessibilityRefreshMessage: String {
        lang == .english
            ? "After updating Voice2Text, macOS invalidates the Accessibility permission. Please open System Settings → Privacy & Security → Accessibility, select Voice2Text and click \"−\" to remove it, then re-add it by clicking \"+\" or relaunch the app."
            : "更新 Voice2Text 后，macOS 会使辅助功能权限失效。请打开系统设置 → 隐私与安全 → 辅助功能，选中 Voice2Text 并点击「−」移除，然后点击「+」重新添加或重新启动应用。"
    }
    static var later: String {
        lang == .english ? "Later" : "稍后"
    }
    static var disableGlobalHotkey: String {
        lang == .english ? "Disable Global Hotkey" : "禁用全局快捷键"
    }

    // MARK: MenuBarView

    static var stopRecording: String {
        lang == .english ? "Stop Recording" : "停止录音"
    }
    static var startRecording: String {
        lang == .english ? "Start Recording" : "开始录音"
    }
    static var output: String {
        lang == .english ? "Output" : "输出"
    }
    static func modelMenu(_ name: String) -> String {
        lang == .english ? "Model: \(name)" : "模型: \(name)"
    }
    static var downloadLabel: String {
        lang == .english ? "(Download)" : "（下载）"
    }
    static var copyTranscription: String {
        lang == .english ? "Copy Transcription" : "复制转写内容"
    }
    static var openWindow: String {
        lang == .english ? "Open Window" : "打开窗口"
    }
    static var settings: String {
        lang == .english ? "Settings..." : "设置…"
    }
    static var punctuationRestore: String {
        lang == .english ? "Punctuation Restore (中+英)" : "标点恢复（中+英）"
    }
    static var quit: String {
        lang == .english ? "Quit" : "退出"
    }

    // MARK: FloatingRecordingPanel

    static var floatingRecording: String {
        lang == .english ? "Recording..." : "录音中…"
    }
    static var floatingTranscribing: String {
        lang == .english ? "Transcribing..." : "转写中…"
    }
    static var floatingPasted: String {
        lang == .english ? "Pasted!" : "已粘贴！"
    }

    // MARK: TranscriptionView

    static var transcriptionPlaceholder: String {
        lang == .english ? "Transcription will appear here" : "转写内容将显示在这里"
    }
    static func charCount(_ count: Int) -> String {
        lang == .english ? "\(count) chars" : "\(count) 字符"
    }

    // MARK: CopyButton

    static var copyTooltip: String {
        lang == .english ? "Copy transcription" : "复制转写内容"
    }

    // MARK: HotkeyRecorderView

    static var pressShortcut: String {
        lang == .english ? "Press shortcut..." : "请按快捷键…"
    }
    static var reset: String {
        lang == .english ? "Reset" : "重置"
    }

    // MARK: SettingsView — Tabs

    static var generalTab: String {
        lang == .english ? "General" : "通用"
    }
    static var modelsTab: String {
        lang == .english ? "Models" : "模型"
    }
    static var shortcutsTab: String {
        lang == .english ? "Shortcuts" : "快捷键"
    }
    static var advancedTab: String {
        lang == .english ? "Advanced" : "高级"
    }

    // MARK: SettingsView — General Tab

    static var languageSection: String {
        lang == .english ? "Language" : "界面语言"
    }
    static var languageLabel: String {
        lang == .english ? "Language" : "语言"
    }
    static var sttEngineSection: String {
        lang == .english ? "Speech-to-Text Engine" : "语音转文字引擎"
    }
    static var engineLabel: String {
        lang == .english ? "Engine" : "引擎"
    }
    static var networkAvailable: String {
        lang == .english ? "Network available" : "网络可用"
    }
    static var noNetworkAppleSpeech: String {
        lang == .english ? "No network — Apple Speech requires internet" : "无网络 — Apple Speech 需要联网"
    }
    static var outputScriptSection: String {
        lang == .english ? "Output Script" : "输出文字"
    }
    static var scriptLabel: String {
        lang == .english ? "Script" : "文字"
    }

    // MARK: SettingsView — Models Tab

    static var selectButton: String {
        lang == .english ? "Select" : "选择"
    }
    static var selectedLabel: String {
        lang == .english ? "Selected" : "已选择"
    }
    static var downloadButton: String {
        lang == .english ? "Download" : "下载"
    }
    static var deleteTooltip: String {
        lang == .english ? "Delete model" : "删除模型"
    }
    static var loading: String {
        lang == .english ? "Loading..." : "加载中…"
    }
    static func downloadingProgress(_ percent: Int) -> String {
        lang == .english ? "Downloading... \(percent)%" : "下载中… \(percent)%"
    }

    // MARK: SettingsView — Shortcuts Tab

    static var globalPushToTalk: String {
        lang == .english ? "Global Push-to-Talk" : "全局按键说话"
    }
    static var enableGlobalHotkey: String {
        lang == .english ? "Enable global hotkey" : "启用全局快捷键"
    }
    static var shortcutLabel: String {
        lang == .english ? "Shortcut" : "快捷键"
    }
    static var hotkeyUsageHint: String {
        lang == .english
            ? "Hold the shortcut from any app to record. Release to transcribe and auto-paste."
            : "在任意应用中按住快捷键录音，松开即可转写并自动粘贴。"
    }
    static var accessibilitySection: String {
        lang == .english ? "Accessibility" : "辅助功能"
    }
    static var accessibilityGrantedStatus: String {
        lang == .english ? "Accessibility granted — auto-paste enabled" : "辅助功能已授权 — 自动粘贴已启用"
    }
    static var accessibilityNotGrantedStatus: String {
        lang == .english ? "Accessibility not granted — auto-paste disabled" : "辅助功能未授权 — 自动粘贴已禁用"
    }
    static var accessibilityWarning: String {
        lang == .english
            ? "Without Accessibility, the global hotkey will still record and copy to clipboard, but cannot auto-paste."
            : "没有辅助功能权限，全局快捷键仍可录音并复制到剪贴板，但无法自动粘贴。"
    }

    // MARK: SettingsView — Advanced Tab

    static var punctuationSection: String {
        lang == .english ? "Punctuation Restoration (Chinese + English only)" : "标点恢复（仅中英文）"
    }
    static var enablePunctuation: String {
        lang == .english ? "Enable punctuation restore" : "启用标点恢复"
    }
    static var punctuationDescription: String {
        lang == .english
            ? "Uses a built-in BERT model to add punctuation to Chinese text. Non-Chinese speech is not affected. When disabled, the zh-wiki-punctuation-restore model is not used."
            : "使用内置 BERT 模型为中文文本添加标点。非中文语音不受影响。禁用后，不使用 zh-wiki-punctuation-restore 模型。"
    }
    static var developerSection: String {
        lang == .english ? "Developer" : "开发者"
    }
    static var devModeToggle: String {
        lang == .english ? "Dev Mode" : "开发模式"
    }
    static var debugLogTitle: String {
        lang == .english ? "Debug Log" : "调试日志"
    }
    static var clear: String {
        lang == .english ? "Clear" : "清除"
    }
    static var copyAll: String {
        lang == .english ? "Copy All" : "全部复制"
    }

    // MARK: SettingsView — AI Services Tab

    static var aiServicesTab: String {
        lang == .english ? "AI Services" : "AI 服务"
    }
    static var postEditProviderSection: String {
        lang == .english ? "Post-Edit Provider" : "后编辑服务"
    }
    static var providerNone: String {
        lang == .english ? "None (disabled)" : "无（禁用）"
    }
    static var providerLocalLLM: String {
        lang == .english ? "Local LLM (offline, on-device)" : "本地 LLM（离线，设备端）"
    }
    static var providerCloudAPI: String {
        lang == .english ? "Cloud API (Anthropic Claude)" : "云端 API（Anthropic Claude）"
    }
    static var localLLMModelSection: String {
        lang == .english ? "Local LLM Model" : "本地 LLM 模型"
    }
    static var recommended: String {
        lang == .english ? "Recommended" : "推荐"
    }
    static var localLLMNotImplemented: String {
        lang == .english ? "Local LLM inference will be available in a future update." : "本地 LLM 推理将在后续版本中提供。"
    }
    static var localLLMDownloadPrompt: String {
        lang == .english ? "Download a model to enable local post-editing. The recommended model (1.5B) offers a good balance of quality and speed." : "下载模型以启用本地后编辑。推荐的 1.5B 模型在质量和速度之间取得了良好的平衡。"
    }
    static var downloadRecommended: String {
        lang == .english ? "Download Recommended Model" : "下载推荐模型"
    }
    static var cloudAPIWarning: String {
        lang == .english
            ? "Your transcription text will be sent to the configured API endpoint."
            : "您的转写文本将被发送到配置的 API 端点。"
    }
    static var apiCredentialsSection: String {
        lang == .english ? "API Credentials" : "API 凭证"
    }
    static var baseURLLabel: String { "BASE_URL" }
    static var baseURLPlaceholder: String { "https://api.anthropic.com" }
    static var modelLabel: String { "MODEL" }
    static var modelPlaceholder: String { AnthropicClient.defaultModel }
    static var apiTokenLabel: String { "API_KEY" }
    static var apiTokenPlaceholder: String { "sk-..." }
    static var saveToken: String {
        lang == .english ? "Save API Key" : "保存 API Key"
    }
    static var deleteToken: String {
        lang == .english ? "Delete API Key" : "删除 API Key"
    }
    static var tokenSaved: String {
        lang == .english ? "API Key saved in Keychain" : "API Key 已保存到钥匙串"
    }
    static var tokenNotSet: String {
        lang == .english ? "No API Key saved" : "未保存 API Key"
    }
    static var tokenIsSet: String {
        lang == .english ? "API Key saved in Keychain" : "API Key 已保存在钥匙串"
    }
    static var checkAPI: String {
        lang == .english ? "Check API" : "检查 API"
    }
    static var checking: String {
        lang == .english ? "Checking..." : "检查中…"
    }
    static func apiValid(_ ms: Int) -> String {
        lang == .english ? "Valid ✓ (\(ms)ms)" : "有效 ✓（\(ms)ms）"
    }
    static func apiInvalid(_ message: String) -> String {
        lang == .english ? "Failed: \(message)" : "失败：\(message)"
    }
    static var postEditReviseSection: String {
        lang == .english ? "Post-Edit Revise" : "后编辑修订"
    }
    static var postEditProviderDescription: String {
        lang == .english
            ? "After transcription, an LLM can post-edit your text:\n• Auto-punctuation for all languages\n• Fix spelling, grammar, and misheard words\n• Improve clarity while preserving meaning"
            : "转写后，LLM 可以对文本进行后编辑：\n• 自动为所有语言添加标点\n• 修正拼写、语法和误听词汇\n• 在保留原意的前提下提升清晰度"
    }
    static var reviseFailedBanner: String {
        lang == .english ? "Revise failed — using original text" : "修订失败 — 使用原始文本"
    }
    static var reviseFailedFallbackBanner: String {
        lang == .english ? "Revise failed — fell back to punctuation restore" : "修订失败 — 已回退到标点修复"
    }
    static var customPromptLabel: String {
        lang == .english ? "Custom Prompt" : "自定义提示词"
    }
    static var resetToDefault: String {
        lang == .english ? "Reset to Default" : "恢复默认"
    }
    static var savePrompt: String {
        lang == .english ? "Save" : "保存"
    }
    static var saved: String {
        lang == .english ? "Saved" : "已保存"
    }
    static var punctuationHandledByRevise: String {
        lang == .english ? "Auto-punctuation is paused — AI Revise handles punctuation" : "自动标点已暂停 — 由 AI 修正处理标点"
    }
    static var reviseExclusivityNote: String {
        lang == .english
            ? "When enabled, punctuation is handled by AI Revise. Auto-punctuation is paused. On failure, falls back to auto-punctuation."
            : "启用后，标点由 AI 修正处理，自动标点暂停。失败时回退到自动标点。"
    }
    static var invalidBaseURL: String {
        lang == .english ? "Invalid URL (must start with http:// or https://)" : "无效 URL（必须以 http:// 或 https:// 开头）"
    }
    static var insecureURLWarning: String {
        lang == .english ? "Warning: HTTP sends credentials in cleartext" : "警告：HTTP 以明文发送凭证"
    }
    static var saveCredentials: String {
        lang == .english ? "Save Credentials" : "保存凭证"
    }
    static var revert: String {
        lang == .english ? "Revert" : "还原"
    }
    static var unsavedChanges: String {
        lang == .english ? "Unsaved changes" : "有未保存的更改"
    }
    static var credentialsSaved: String {
        lang == .english ? "Saved" : "已保存"
    }

    // MARK: Punctuation Model

    static var downloadPunctuationModel: String {
        lang == .english ? "Download Punctuation Model" : "下载标点模型"
    }
    static var deletePunctuationModel: String {
        lang == .english ? "Delete Model" : "删除模型"
    }
    static var punctuationModelDownloaded: String {
        lang == .english ? "Punctuation model loaded" : "标点模型已加载"
    }
    static var punctuationModelSizeNote: String {
        lang == .english ? "~100 MB download (CoreML BERT model)" : "约 100 MB 下载（CoreML BERT 模型）"
    }

    // MARK: What's New

    static func whatsNewTitle(_ version: String) -> String {
        lang == .english ? "What's New in v\(version)" : "v\(version) 新功能"
    }
}
