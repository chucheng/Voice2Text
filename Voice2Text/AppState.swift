import Foundation
import SwiftUI
import AVFoundation
import Network
import Speech

enum WhisperModel: String, CaseIterable, Identifiable {
    case tiny = "tiny"
    case base = "base"
    case small = "small"
    case medium = "medium"
    case largeTurbo = "large-v3-turbo"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .tiny: return "Tiny (~75 MB)"
        case .base: return "Base (~142 MB)"
        case .small: return "Small (~466 MB)"
        case .medium: return "Medium (~1.5 GB)"
        case .largeTurbo: return "Large v3 Turbo (~1.6 GB)"
        }
    }

    var fileName: String { "ggml-\(rawValue).bin" }

    var downloadURL: URL {
        URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/\(fileName)")!
    }
}

enum OutputScript: String, CaseIterable, Identifiable {
    case traditional = "繁體"
    case simplified = "简体"

    var id: String { rawValue }
}

enum STTEngine: String, CaseIterable, Identifiable {
    case whisper = "Whisper"
    case apple = "Apple Speech"

    var id: String { rawValue }
}

enum PostEditProvider: String, CaseIterable, Identifiable {
    case none = "none"
    case localLLM = "localLLM"
    case cloudAPI = "cloudAPI"

    var id: String { rawValue }
}

enum LocalLLMModel: String, CaseIterable, Identifiable {
    // Qwen 3.5 (recommended, shown first in UI)
    case qwen35_08B = "qwen3.5-0.8b"
    case qwen35_2B  = "qwen3.5-2b"
    case qwen35_4B  = "qwen3.5-4b"
    // Qwen 2.5 (legacy)
    case qwen05B = "qwen2.5-0.5b"
    case qwen15B = "qwen2.5-1.5b"
    case qwen3B  = "qwen2.5-3b"
    case qwen7B  = "qwen2.5-7b"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .qwen05B:    return "Qwen 2.5 0.5B (~400 MB)"
        case .qwen15B:    return "Qwen 2.5 1.5B (~1.0 GB)"
        case .qwen3B:     return "Qwen 2.5 3B (~2.0 GB)"
        case .qwen7B:     return "Qwen 2.5 7B (~3.5 GB)"
        case .qwen35_08B: return "Qwen 3.5 0.8B (~500 MB)"
        case .qwen35_2B:  return "Qwen 3.5 2B (~1.3 GB)"
        case .qwen35_4B:  return "Qwen 3.5 4B (~2.5 GB)"
        }
    }

    var isRecommended: Bool { self == .qwen35_2B }

    var isQwen35: Bool {
        switch self {
        case .qwen35_08B, .qwen35_2B, .qwen35_4B: return true
        default: return false
        }
    }

    var fileName: String {
        switch self {
        case .qwen05B:    return "qwen2.5-0.5b-instruct-q4_k_m.gguf"
        case .qwen15B:    return "qwen2.5-1.5b-instruct-q4_k_m.gguf"
        case .qwen3B:     return "qwen2.5-3b-instruct-q4_k_m.gguf"
        case .qwen7B:     return "qwen2.5-7b-instruct-q3_k_m.gguf"
        case .qwen35_08B: return "Qwen3.5-0.8B-Q4_K_M.gguf"
        case .qwen35_2B:  return "Qwen3.5-2B-Q4_K_M.gguf"
        case .qwen35_4B:  return "Qwen3.5-4B-Q4_K_M.gguf"
        }
    }

    var downloadURL: URL {
        switch self {
        case .qwen05B, .qwen15B, .qwen3B, .qwen7B:
            // Qwen 2.5 — official Qwen GGUF repos
            let repoName: String
            switch self {
            case .qwen05B: repoName = "Qwen2.5-0.5B-Instruct-GGUF"
            case .qwen15B: repoName = "Qwen2.5-1.5B-Instruct-GGUF"
            case .qwen3B:  repoName = "Qwen2.5-3B-Instruct-GGUF"
            case .qwen7B:  repoName = "Qwen2.5-7B-Instruct-GGUF"
            default: fatalError()
            }
            return URL(string: "https://huggingface.co/Qwen/\(repoName)/resolve/main/\(fileName)")!
        case .qwen35_08B, .qwen35_2B, .qwen35_4B:
            // Qwen 3.5 — unsloth community GGUF repos
            let repoName: String
            switch self {
            case .qwen35_08B: repoName = "Qwen3.5-0.8B-GGUF"
            case .qwen35_2B:  repoName = "Qwen3.5-2B-GGUF"
            case .qwen35_4B:  repoName = "Qwen3.5-4B-GGUF"
            default: fatalError()
            }
            return URL(string: "https://huggingface.co/unsloth/\(repoName)/resolve/main/\(fileName)")!
        }
    }
}

class AppState: ObservableObject {
    static let shared = AppState()

    @Published var isRecording = false
    @Published var isStarting = false
    @Published var isTranscribing = false
    @Published var transcriptionText = ""
    @Published var isReformatting = false
    @Published var outputScript: OutputScript = {
        if let saved = UserDefaults.standard.string(forKey: "outputScript"),
           let script = OutputScript(rawValue: saved) {
            return script
        }
        return .simplified
    }() {
        didSet { UserDefaults.standard.set(outputScript.rawValue, forKey: "outputScript") }
    }
    @Published var selectedModel: WhisperModel = {
        if let saved = UserDefaults.standard.string(forKey: "selectedModel"),
           let model = WhisperModel(rawValue: saved) {
            return model
        }
        // No saved default: pick the largest downloaded model, or fall back to .base
        let dir = AppState.modelDirectory
        for model in WhisperModel.allCases.reversed() {
            let path = dir.appendingPathComponent(model.fileName)
            if FileManager.default.fileExists(atPath: path.path) {
                return model
            }
        }
        return .base
    }()
    @Published var isModelLoaded = false
    @Published var isDownloadingModel = false
    @Published var downloadProgress: Double = 0
    @Published var loadedModelName: String = ""
    @Published var sttEngine: STTEngine = .whisper
    @Published var isNetworkAvailable = false
    @Published var uiLanguage: UILanguage = {
        if let saved = UserDefaults.standard.string(forKey: "uiLanguage"),
           let lang = UILanguage(rawValue: saved) {
            return lang
        }
        return UILanguage.systemDefault
    }() {
        didSet { UserDefaults.standard.set(uiLanguage.rawValue, forKey: "uiLanguage") }
    }
    // MARK: - Dangerous Zone (Anthropic API)
    @Published var dangerousZoneBaseURL: String = UserDefaults.standard.string(forKey: "dzBaseURL") ?? "" {
        didSet { UserDefaults.standard.set(dangerousZoneBaseURL, forKey: "dzBaseURL") }
    }
    @Published var dangerousZoneModel: String = UserDefaults.standard.string(forKey: "dzModel") ?? AnthropicClient.defaultModel {
        didSet { UserDefaults.standard.set(dangerousZoneModel, forKey: "dzModel") }
    }
    @Published var dangerousZoneTokenIsSet = false
    @Published var apiCheckState: APICheckResult = .unchecked
    @Published var reviseFailed = false
    @Published var reviseFailedWithFallback = false
    @Published var lowAudioWarning = false
    @Published var customRevisePrompt: String = {
        let stored = UserDefaults.standard.string(forKey: "customRevisePrompt")
        // Migrate: empty or matching a known old default → use current default
        if stored == nil || stored!.isEmpty { return AnthropicClient.revisePrompt }
        // Detect old default prompt by its unique first rule (removed in v1.9.0)
        if stored!.contains("Improve clarity only when the meaning is clearly implied by the context.") {
            return AnthropicClient.revisePrompt
        }
        return stored!
    }() {
        didSet { UserDefaults.standard.set(customRevisePrompt, forKey: "customRevisePrompt") }
    }

    // MARK: - Post-Edit Provider & Local LLM
    /// Temporarily bypass post-edit LLM — pipeline falls back to BERT/raw text.
    /// Model stays loaded so resume is instant.
    @Published var isPostEditPaused = false

    @Published var postEditProvider: PostEditProvider = {
        if let saved = UserDefaults.standard.string(forKey: "postEditProvider"),
           let provider = PostEditProvider(rawValue: saved) {
            return provider
        }
        return .localLLM
    }() {
        didSet {
            UserDefaults.standard.set(postEditProvider.rawValue, forKey: "postEditProvider")
            isPostEditPaused = false
            if postEditProvider == .cloudAPI {
                // Auto-check API when switching to Cloud API if credentials exist
                ensureCloudAPIReady()
            }
            // Unload Local LLM model when switching away from Local LLM provider
            if postEditProvider != .localLLM && (isLocalLLMModelLoaded || isLoadingLocalLLMModel) {
                log("Local LLM: unloading model (switched away from Local LLM provider)")
                isLocalLLMModelLoaded = false
                isLoadingLocalLLMModel = false
                llamaBridge.freeModelAsync()
            }
        }
    }
    @Published var selectedLocalLLMModel: LocalLLMModel = {
        if let saved = UserDefaults.standard.string(forKey: "selectedLocalLLMModel"),
           let model = LocalLLMModel(rawValue: saved) {
            return model
        }
        return .qwen35_2B
    }() {
        didSet { UserDefaults.standard.set(selectedLocalLLMModel.rawValue, forKey: "selectedLocalLLMModel") }
    }
    @Published var isDownloadingLocalLLM = false
    @Published var localLLMDownloadProgress: Double = 0
    @Published var downloadingLocalLLMModel: LocalLLMModel?  // which model is downloading
    private var localLLMDownloadTask: URLSessionDownloadTask?
    @Published var isLocalLLMModelLoaded = false
    @Published var isLoadingLocalLLMModel = false  // model load in progress

    @Published var usePunctuationRestore = false

    // MARK: - Punctuation Model (CoreML)
    let punctuationRestorer = PunctuationRestorer()
    @Published var isPunctuationModelLoaded = false
    @Published var isDownloadingPunctuationModel = false
    @Published var punctuationModelDownloadProgress: Double = 0

    var isPunctuationModelDownloaded: Bool {
        PunctuationRestorer.isModelDownloaded
    }
    @Published var audioLevel: Float = 0
    @Published var devMode: Bool = UserDefaults.standard.bool(forKey: "devMode") {
        didSet { UserDefaults.standard.set(devMode, forKey: "devMode") }
    }
    @Published var debugLog: [String] = []
    @AppStorage("showFirstUseTooltip") var showFirstUseTooltip = true
    @AppStorage("onboardingCompleted") var onboardingCompleted = false
    @AppStorage("lastSeenVersion") var lastSeenVersion = ""
    @Published var showWhatsNew = false
    var whatsNewEntries: [WhatsNewEntry] = []
    @AppStorage("globalHotkeyEnabled") var globalHotkeyEnabled = true
    @AppStorage("accessibilityWasGranted") var accessibilityWasGranted = false
    @Published var isAccessibilityGranted = false
    @Published var isGlobalHotkeyActive = false
    @Published var showMicrophoneAlert = false
    @Published var showAccessibilityAlert = false
    @Published var showAccessibilityUpgradeAlert = false
    @Published var isMicrophoneGranted = false

    /// When true, the Apple Speech final result should trigger post-processing.
    private var pendingAppleSpeechPostProcess = false

    private let networkMonitor = NWPathMonitor()
    private var keyDownMonitor: Any?
    private var keyUpMonitor: Any?
    private var spaceHeld = false

    // MARK: - Pipeline Timing (dev mode only)
    private var pipelineStartTime: Date?
    private var stageStartTime: Date?

    /// Weak reference to the main window, captured by WindowAccessor.
    /// Used by AppDelegate to reopen the window on Dock icon click.
    weak var mainWindow: NSWindow?

    let audioRecorder = AudioRecorder()
    let whisperBridge = WhisperBridge()
    let llamaBridge = LlamaBridge()
    let appleSpeech = AppleSpeechRecognizer()
    private(set) var anthropicClient: AnthropicClient?
    private var appleSpeechRequest: SFSpeechAudioBufferRecognitionRequest?

    /// Raw transcription text from whisper (before language conversion).
    private var rawTranscription = ""

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f
    }()

    /// Log a debug message. Only records when Dev Mode is enabled.
    func log(_ message: String) {
        guard devMode else { return }
        let ts = Self.dateFormatter.string(from: Date())
        debugLog.append("[\(ts)] \(message)")
        // Keep last 500 lines
        if debugLog.count > 500 { debugLog.removeFirst(debugLog.count - 500) }
    }

    private init() {
        let appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let buildNumber = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
        log("Voice2Text v\(appVersion) (build \(buildNumber)) starting")
        log("STT engine: \(sttEngine.rawValue), model: \(selectedModel.rawValue), script: \(outputScript.rawValue)")
        log("UI language: \(uiLanguage.rawValue)")
        log("Post-edit provider: \(postEditProvider.rawValue), local model: \(selectedLocalLLMModel.displayName)")

        if customRevisePrompt != AnthropicClient.revisePrompt {
            log("Custom revise prompt: \(customRevisePrompt.count) chars")
        }

        // Wire audio level callback
        audioRecorder.onAudioLevel = { [weak self] level in
            self?.audioLevel = level
            self?.vadProcessAudioLevel(level)
            if self?.isGlobalHotkeyActive == true {
                FloatingRecordingPanel.shared.updateAudioLevel(level)
            }
        }

        // Monitor network for Apple Speech
        networkMonitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                let available = path.status == .satisfied
                self?.isNetworkAvailable = available
                self?.log("Network status changed: \(available ? "connected" : "disconnected") (affects Apple Speech)")
            }
        }
        networkMonitor.start(queue: DispatchQueue(label: "com.voice2text.network"))

        loadModelIfAvailable()
        loadLocalLLMModelIfAvailable()
        setupKeyboardShortcuts()
        loadPunctuationModelIfAvailable()
        migratePunctuationServer()

        // Cloud API: don't read Keychain on launch — wait for user interaction
        // (badge tap, settings open, or actual transcription triggers ensureCloudAPIReady)

        setupGlobalHotkey()
        refreshAccessibilityStatus()
        // Delay permission checks to allow SwiftUI view to be ready for alerts
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.checkPermissionsOnLaunch()
            self?.checkWhatsNew()
        }

    }

    // MARK: - What's New

    private func checkWhatsNew() {
        guard onboardingCompleted else { return }
        let currentVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
        guard !currentVersion.isEmpty, currentVersion != lastSeenVersion else { return }
        let entries = WhatsNewLoader.entriesForMinor(of: currentVersion)
        if !entries.isEmpty {
            whatsNewEntries = entries
            withAnimation { showWhatsNew = true }
            log("What's New: showing \(entries.count) entries for v\(currentVersion)")
        }
        lastSeenVersion = currentVersion
    }

    func dismissWhatsNew() {
        withAnimation { showWhatsNew = false }
        whatsNewEntries = []
    }

    // MARK: - Push-to-Talk (Spacebar)

    private func isTextFieldFocused() -> Bool {
        guard let responder = NSApp.keyWindow?.firstResponder else { return false }
        return responder is NSTextView || responder is NSTextField
    }

    /// Returns the selected text in the currently focused NSTextView, if any.
    private func selectedTextInFocusedView() -> String? {
        guard let textView = NSApp.keyWindow?.firstResponder as? NSTextView else { return nil }
        let range = textView.selectedRange()
        guard range.length > 0, let str = textView.string as NSString? else { return nil }
        return str.substring(with: range)
    }

    private func setupKeyboardShortcuts() {
        keyDownMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }

            // Cmd+C: copy full transcription when nothing is selected
            if event.modifierFlags.contains(.command),
               event.charactersIgnoringModifiers == "c",
               !self.transcriptionText.isEmpty {
                // If text is selected in a text view, let native copy handle it
                if let selected = self.selectedTextInFocusedView(), !selected.isEmpty {
                    return event
                }
                // Otherwise copy entire transcription
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(self.transcriptionText, forType: .string)
                self.log("Cmd+C: copied full transcription (\(self.transcriptionText.count) chars)")
                return nil
            }

            // Spacebar push-to-talk
            guard event.keyCode == 49,       // spacebar
                  !self.isTextFieldFocused() // don't capture when editing text
            else { return event }

            // If already holding space, consume repeats silently (prevent system beep)
            if self.spaceHeld {
                return nil
            }

            guard !event.isARepeat else { return nil } // consume repeats even before hold starts

            if !self.isRecording && self.canToggle {
                self.spaceHeld = true
                self.toggleRecording()
                self.log("Push-to-talk: started (spacebar down)")
            }
            return nil // consume the event
        }

        keyUpMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyUp) { [weak self] event in
            guard let self,
                  event.keyCode == 49   // spacebar
            else { return event }

            if self.spaceHeld {
                self.spaceHeld = false
                if self.isRecording {
                    self.toggleRecording()
                    self.log("Push-to-talk: stopped (spacebar up)")
                }
                return nil // consume only when push-to-talk was active
            }
            return event // pass through normal space key ups
        }
    }

    var canToggle: Bool {
        if sttEngine == .apple {
            return !isStarting && !isTranscribing && isNetworkAvailable
        }
        return !isStarting && !isTranscribing && isModelLoaded
    }

    func toggleRecording() {
        guard canToggle else { return }

        if isRecording {
            if sttEngine == .apple {
                stopAppleSpeech()
            } else {
                stopAndTranscribe()
            }
        } else {
            if sttEngine == .apple {
                startAppleSpeech()
            } else {
                isStarting = true
                audioRecorder.startRecording { [weak self] success in
                    self?.isStarting = false
                    self?.isRecording = success
                    if success {
                        self?.vadStartRecording()
                    }
                }
            }
        }
    }

    // MARK: - Whisper

    private func stopAndTranscribe() {
        vadStopRecording()
        pipelineStartTime = Date()
        let samples = audioRecorder.stopRecording()
        isRecording = false
        audioLevel = 0

        guard !samples.isEmpty else {
            transcriptionText = ""
            if isGlobalHotkeyActive {
                isGlobalHotkeyActive = false
                FloatingRecordingPanel.shared.hide()
            }
            return
        }

        if isGlobalHotkeyActive {
            FloatingRecordingPanel.shared.show(state: .transcribing)
        }

        log("Audio recorded: \(samples.count) samples (\(String(format: "%.1f", Double(samples.count) / 16000))s @ 16kHz)")

        // Check for low audio level (wrong mic / near-silence)
        let sumOfSquares = samples.reduce(Float(0)) { $0 + $1 * $1 }
        let rms = sqrt(sumOfSquares / Float(samples.count))
        if rms < 0.005 {
            log("⚠️ Low audio level detected: RMS=\(String(format: "%.6f", rms)) — check microphone settings")
            showLowAudioWarning()
        }

        isTranscribing = true
        stageStartTime = Date()
        transcribe(samples: samples, language: "auto")
    }

    // MARK: - Apple Speech

    private func startAppleSpeech() {
        isStarting = true
        appleSpeech.requestPermission { [weak self] granted in
            guard let self, granted else {
                self?.isStarting = false
                self?.log("Apple Speech: microphone/speech permission denied by user")
                return
            }
            self.transcriptionText = ""
            self.appleSpeechRequest = self.appleSpeech.startRecognition(
                onResult: { [weak self] text, isFinal in
                    guard let self else { return }
                    self.transcriptionText = self.convertScript(text)
                    if isFinal {
                        self.rawTranscription = text
                        self.log("Apple Speech: final result (\(text.count) chars)")
                        if self.pendingAppleSpeechPostProcess {
                            self.pendingAppleSpeechPostProcess = false
                            self.postProcess(text)
                        }
                    }
                },
                onError: { [weak self] error in
                    guard let self else { return }
                    self.log("Apple Speech error: \(error)")
                    // If waiting for final result to post-process, fall back to current text
                    if self.pendingAppleSpeechPostProcess {
                        self.pendingAppleSpeechPostProcess = false
                        self.rawTranscription = self.transcriptionText
                        self.isReformatting = false
                        self.performAutoPaste(self.transcriptionText)
                    }
                }
            )

            guard self.appleSpeechRequest != nil else {
                self.isStarting = false
                self.log("Apple Speech: failed to start")
                return
            }

            // Start audio engine and feed buffers to Apple Speech
            self.audioRecorder.startRecording(tapHandler: { [weak self] buffer in
                self?.appleSpeechRequest?.append(buffer)
            }) { [weak self] success in
                self?.isStarting = false
                self?.isRecording = success
                self?.log("Apple Speech: recording \(success ? "started successfully" : "failed to start (audio engine error)")")
            }
        }
    }

    private func stopAppleSpeech() {
        pipelineStartTime = Date()
        audioRecorder.stopRecording()
        isRecording = false
        audioLevel = 0
        log("Apple Speech: recognition stopped, processing final result...")

        // If any post-edit provider is active, wait for isFinal before post-processing
        if postEditProvider != .none {
            pendingAppleSpeechPostProcess = true
            isReformatting = true
            if isGlobalHotkeyActive {
                FloatingRecordingPanel.shared.show(state: .transcribing)
            }
            // endAudio + finish triggers final result callback
            appleSpeech.stopRecognition()
            appleSpeechRequest = nil
            // Safety timeout: if isFinal never arrives, fall back after 5s
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
                guard let self, self.pendingAppleSpeechPostProcess else { return }
                self.pendingAppleSpeechPostProcess = false
                self.log("Apple Speech: no final result after timeout, using partial transcription as-is")
                self.rawTranscription = self.transcriptionText
                self.isReformatting = false
                self.performAutoPaste(self.transcriptionText)
            }
        } else {
            appleSpeech.stopRecognition()
            appleSpeechRequest = nil
            rawTranscription = transcriptionText
            performAutoPaste(transcriptionText)
        }
    }

    /// Normalize audio to target RMS level (~-20 dBFS) for consistent Whisper accuracy regardless of mic volume.
    private func normalizeAudio(_ samples: [Float]) -> [Float] {
        guard !samples.isEmpty else { return samples }
        let sumOfSquares = samples.reduce(Float(0)) { $0 + $1 * $1 }
        let rms = sqrt(sumOfSquares / Float(samples.count))
        guard rms > 0.0001 else { return samples }  // near-silence, don't amplify noise
        let targetRMS: Float = 0.1  // ~-20 dBFS
        let scale = targetRMS / rms
        if devMode { log("Audio normalize: RMS=\(String(format: "%.4f", rms)) → scale=\(String(format: "%.2f", scale))x") }
        return samples.map { min(max($0 * scale, -1.0), 1.0) }
    }

    private func transcribe(samples: [Float], language: String) {
        let normalized = normalizeAudio(samples)
        log("Whisper: inference started (language=\(language), model=\(selectedModel.rawValue))")
        whisperBridge.transcribe(samples: normalized, language: language) { [weak self] text in
            guard let self else { return }
            if self.devMode, let start = self.stageStartTime {
                let ms = Int(Date().timeIntervalSince(start) * 1000)
                self.log("⏱ Whisper STT: \(ms)ms")
            }
            self.log("Whisper: inference complete, result: \(text.count) chars")

            // If auto-detected and result contains non-Chinese/English text, retry with "zh"
            if language == "auto" && self.containsUnexpectedLanguage(text) {
                self.log("Whisper: detected mixed Chinese + unexpected language, retrying with language=zh")
                self.transcribe(samples: samples, language: "zh")
                return
            }

            self.rawTranscription = text
            self.isTranscribing = false
            self.postProcess(text)
        }
    }

    /// Returns true if text contains characters that are not Chinese, English, or common punctuation/numbers.
    /// Only triggers retry when text also contains some Chinese (partial misdetection).
    /// If text is purely another language (no Chinese at all), accepts it as-is.
    private func containsUnexpectedLanguage(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }

        // If no Chinese characters at all, it's likely a different language — don't retry with "zh"
        guard textContainsChinese(trimmed) else { return false }

        for scalar in trimmed.unicodeScalars {
            // Allow: ASCII (English + numbers + punctuation), CJK Unified Ideographs,
            // CJK punctuation, common whitespace/newlines
            let v = scalar.value
            let isASCII = v <= 0x7F
            let isCJK = (0x4E00...0x9FFF).contains(v)
            let isCJKExtA = (0x3400...0x4DBF).contains(v)
            let isCJKCompat = (0xF900...0xFAFF).contains(v)
            let isCJKPunct = (0x3000...0x303F).contains(v)
            let isFullwidth = (0xFF00...0xFFEF).contains(v)
            let isBopomofo = (0x3100...0x312F).contains(v)
            let isGenPunct = (0x2000...0x206F).contains(v)

            if isASCII || isCJK || isCJKExtA || isCJKCompat || isCJKPunct || isFullwidth || isBopomofo || isGenPunct {
                continue
            }
            // Found a character outside expected range
            return true
        }
        return false
    }

    /// Returns true if the text contains any CJK Unified Ideograph characters.
    private func textContainsChinese(_ text: String) -> Bool {
        for scalar in text.unicodeScalars {
            let v = scalar.value
            if (0x4E00...0x9FFF).contains(v) || (0x3400...0x4DBF).contains(v) || (0xF900...0xFAFF).contains(v) {
                return true
            }
        }
        return false
    }

    // MARK: - Punctuation Model

    /// Load the CoreML punctuation model if already downloaded.
    func loadPunctuationModelIfAvailable() {
        guard isPunctuationModelDownloaded else {
            log("BERT punctuation model: not downloaded")
            isPunctuationModelLoaded = false
            usePunctuationRestore = false
            return
        }
        log("BERT punctuation model: found on disk, loading CoreML model...")
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            let success = self.punctuationRestorer.loadModel()
            DispatchQueue.main.async {
                self.isPunctuationModelLoaded = success
                if success {
                    self.usePunctuationRestore = true
                    self.log("BERT punctuation model: loaded, enabled by default")
                } else {
                    self.usePunctuationRestore = false
                    self.log("BERT punctuation model: failed to load")
                }
            }
        }
    }

    /// Remove legacy PunctuationServer.app if present in Application Support.
    private func migratePunctuationServer() {
        let legacyPath = Self.modelDirectory.appendingPathComponent("PunctuationServer.app")
        if FileManager.default.fileExists(atPath: legacyPath.path) {
            do {
                try FileManager.default.removeItem(at: legacyPath)
                log("Migration: removed legacy PunctuationServer.app from \(legacyPath.path)")
            } catch {
                log("Migration: failed to remove legacy PunctuationServer.app — \(error.localizedDescription)")
            }
        }
    }

    /// Post-process whisper output: punctuation restore → LLM reformat → script conversion.
    /// When any post-edit provider is active, BERT punctuation is skipped (LLM handles it).
    /// On LLM failure, falls back to BERT if available.
    private func postProcess(_ text: String) {
        isReformatting = true
        let effectiveProvider = isPostEditPaused ? PostEditProvider.none : postEditProvider
        log("Post-process: provider=\(effectiveProvider.rawValue)\(isPostEditPaused ? " (paused)" : ""), input=\(text.count) chars")
        if devMode {
            log("  → Raw input: \(text)")
        }

        // When any post-edit provider is active, skip BERT — LLM handles punctuation
        if effectiveProvider == .localLLM {
            stageStartTime = Date()
            applyLocalLLMAndConvert(text)
        } else if effectiveProvider == .cloudAPI {
            // Lazy init: build client on first use if not yet loaded
            if anthropicClient == nil {
                loadTokenFromKeychain()
                rebuildAnthropicClient()
            }
            stageStartTime = Date()
            applyLLMAndConvert(text)
        } else if usePunctuationRestore && isPunctuationModelLoaded && textContainsChinese(text) {
            log("BERT punctuation restore: sending \(text.count) chars to CoreML model...")
            stageStartTime = Date()
            punctuationRestorer.restore(text) { [weak self] restored, error in
                guard let self else { return }
                if self.devMode, let start = self.stageStartTime {
                    let ms = Int(Date().timeIntervalSince(start) * 1000)
                    self.log("⏱ BERT punctuation: \(ms)ms")
                }
                if let restored {
                    self.log("BERT punctuation restore: success (\(restored.count) chars)")
                    self.rawTranscription = restored
                    self.applyLLMAndConvert(restored)
                } else {
                    self.log("BERT punctuation restore failed: \(error ?? "unknown"), using raw text without punctuation")
                    self.applyLLMAndConvert(text)
                }
            }
        } else {
            applyLLMAndConvert(text)
        }
    }

    /// Apply Local LLM post-edit (Qwen) then script conversion.
    /// Falls back to BERT if model not downloaded or inference fails.
    private func applyLocalLLMAndConvert(_ text: String) {
        if !isLocalLLMModelDownloaded(selectedLocalLLMModel) {
            log("Local LLM: model \(selectedLocalLLMModel.displayName) not downloaded, skipping post-edit")
            applyBERTFallbackAndConvert(text)
            return
        }

        if !isLocalLLMModelLoaded {
            if isLoadingLocalLLMModel {
                log("Local LLM: model load in progress, falling back to BERT")
                applyBERTFallbackAndConvert(text)
                return
            }
            log("Local LLM: loading \(selectedLocalLLMModel.displayName)...")
            isLoadingLocalLLMModel = true
            let model = selectedLocalLLMModel
            let modelPath = localLLMModelPath(for: model).path
            llamaBridge.loadModel(path: modelPath) { [weak self] success in
                guard let self else { return }
                self.isLoadingLocalLLMModel = false
                // Check that provider/model hasn't changed while loading
                guard self.postEditProvider == .localLLM,
                      self.selectedLocalLLMModel == model else {
                    self.log("Local LLM: provider or model changed during load, discarding")
                    if success { self.llamaBridge.freeModelAsync() }
                    self.logPipelineTotal()
                    self.isReformatting = false
                    return
                }
                if success {
                    self.isLocalLLMModelLoaded = true
                    self.log("Local LLM: model loaded successfully")
                    self.runLocalLLMInference(text)
                } else {
                    self.log("Local LLM: failed to load model — deleting corrupt file, falling back to BERT")
                    try? FileManager.default.removeItem(atPath: modelPath)
                    self.applyBERTFallbackAndConvert(text)
                }
            }
            return
        }

        runLocalLLMInference(text)
    }

    /// Run inference on the loaded Local LLM model.
    private func runLocalLLMInference(_ text: String) {
        let prompt = customRevisePrompt
        let useNoThink = selectedLocalLLMModel.isQwen35
        log("Local LLM: sending \(text.count) chars for revision\(useNoThink ? " (noThink)" : "")")
        if devMode {
            log("  → Input: \(text)")
        }
        let llmStart = Date()
        llamaBridge.generate(text: text, systemPrompt: prompt, noThink: useNoThink) { [weak self] result in
            guard let self else { return }
            if self.devMode {
                let ms = Int(Date().timeIntervalSince(llmStart) * 1000)
                self.log("⏱ Local LLM round-trip: \(ms)ms")
            }
            if let result, !result.isEmpty {
                // Strip <think>...</think> blocks (safety net for Qwen 3.5)
                let cleaned = Self.stripThinkTags(result)
                if cleaned.isEmpty {
                    self.log("Local LLM: output was only <think> tags, falling back to BERT")
                    self.applyBERTFallbackAndConvert(text)
                    return
                }
                self.log("Local LLM: success (\(cleaned.count) chars)")
                if self.devMode {
                    self.log("  ← Output: \(cleaned)")
                }
                self.rawTranscription = cleaned
                self.transcriptionText = self.convertScript(cleaned)
                self.logPipelineTotal()
                self.isReformatting = false
                self.performAutoPaste(self.transcriptionText)
            } else {
                self.log("Local LLM: inference returned empty, falling back to BERT")
                self.applyBERTFallbackAndConvert(text)
            }
        }
    }

    /// Strip `<think>...</think>` blocks from LLM output (Qwen 3.5 reasoning mode safety net).
    static func stripThinkTags(_ text: String) -> String {
        text.replacingOccurrences(of: "<think>[\\s\\S]*?</think>", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Log total pipeline duration (from spacebar release to final output). Dev mode only.
    private func logPipelineTotal() {
        if devMode, let start = pipelineStartTime {
            let ms = Int(Date().timeIntervalSince(start) * 1000)
            log("⏱ Total (release → done): \(ms)ms")
        }
    }

    /// Try BERT punctuation as best-effort, then script-convert and finish.
    private func applyBERTFallbackAndConvert(_ text: String) {
        if usePunctuationRestore && isPunctuationModelLoaded && textContainsChinese(text) {
            log("BERT fallback: sending \(text.count) chars to CoreML model...")
            let bertStart = Date()
            punctuationRestorer.restore(text) { [weak self] restored, error in
                guard let self else { return }
                if self.devMode {
                    let ms = Int(Date().timeIntervalSince(bertStart) * 1000)
                    self.log("⏱ BERT fallback: \(ms)ms")
                }
                if let restored {
                    self.log("BERT fallback: success (\(restored.count) chars)")
                    self.rawTranscription = restored
                    self.transcriptionText = self.convertScript(restored)
                } else {
                    self.log("BERT fallback failed: \(error ?? "unknown")")
                    self.transcriptionText = self.convertScript(text)
                }
                self.logPipelineTotal()
                self.isReformatting = false
                self.performAutoPaste(self.transcriptionText)
            }
        } else {
            transcriptionText = convertScript(text)
            logPipelineTotal()
            isReformatting = false
            performAutoPaste(transcriptionText)
        }
    }

    /// Apply Cloud API Post-Edit Revise (if enabled) then script conversion.
    /// On LLM failure, falls back to BERT punctuation model if loaded + Chinese text.
    private func applyLLMAndConvert(_ text: String) {
        if postEditProvider == .cloudAPI, let client = anthropicClient {
            let prompt = (customRevisePrompt == AnthropicClient.revisePrompt) ? nil : customRevisePrompt
            log("Post-Edit Revise: sending \(text.count) chars...")
            log("  → Input: \(text)")
            let apiStart = Date()
            client.reviseText(text, prompt: prompt) { [weak self] result, error in
                guard let self else { return }
                if self.devMode {
                    let ms = Int(Date().timeIntervalSince(apiStart) * 1000)
                    self.log("⏱ Cloud API round-trip: \(ms)ms")
                }
                if let result {
                    self.log("Post-Edit Revise: success (\(result.count) chars)")
                    self.log("  ← Output: \(result)")
                    self.transcriptionText = self.convertScript(result)
                    self.logPipelineTotal()
                    self.isReformatting = false
                    self.performAutoPaste(self.transcriptionText)
                } else {
                    self.log("Post-Edit Revise failed: \(error ?? "unknown"). Attempting BERT fallback...")
                    self.tryBERTFallback(text)
                }
            }
        } else {
            transcriptionText = convertScript(text)
            logPipelineTotal()
            isReformatting = false
            performAutoPaste(transcriptionText)
        }
    }

    /// On LLM failure, try BERT punctuation as fallback. If unavailable, use raw text.
    private func tryBERTFallback(_ text: String) {
        if isPunctuationModelLoaded && textContainsChinese(text) {
            log("BERT fallback: sending \(text.count) chars...")
            let bertStart = Date()
            punctuationRestorer.restore(text) { [weak self] restored, error in
                guard let self else { return }
                if self.devMode {
                    let ms = Int(Date().timeIntervalSince(bertStart) * 1000)
                    self.log("⏱ BERT fallback: \(ms)ms")
                }
                if let restored {
                    self.log("BERT fallback: success (\(restored.count) chars)")
                    self.rawTranscription = restored
                    self.transcriptionText = self.convertScript(restored)
                    self.showReviseFailedWithFallback()
                } else {
                    self.log("BERT fallback also failed: \(error ?? "unknown"). Using raw text.")
                    self.transcriptionText = self.convertScript(text)
                    self.showReviseFailed()
                }
                self.logPipelineTotal()
                self.isReformatting = false
                self.performAutoPaste(self.transcriptionText)
            }
        } else {
            log("BERT fallback unavailable. Using raw text.")
            transcriptionText = convertScript(text)
            showReviseFailed()
            logPipelineTotal()
            isReformatting = false
            performAutoPaste(transcriptionText)
        }
    }

    func updateDisplayScript() {
        guard !rawTranscription.isEmpty else { return }
        transcriptionText = convertScript(rawTranscription)
    }

    private func convertScript(_ text: String) -> String {
        switch outputScript {
        case .traditional:
            return text.applyingTransform(StringTransform("Hans-Hant"), reverse: false) ?? text
        case .simplified:
            return text.applyingTransform(StringTransform("Hant-Hans"), reverse: false) ?? text
        }
    }

    // MARK: - Dangerous Zone (API)

    func saveDangerousZoneToken(_ token: String) {
        if token.isEmpty {
            KeychainHelper.deleteToken()
            cachedToken = nil
            dangerousZoneTokenIsSet = false
        } else {
            let saved = KeychainHelper.saveToken(token)
            cachedToken = saved ? token : nil
            dangerousZoneTokenIsSet = saved
        }
        rebuildAnthropicClient()
        resetAPICheckState()
    }

    func deleteDangerousZoneToken() {
        KeychainHelper.deleteToken()
        cachedToken = nil
        dangerousZoneTokenIsSet = false
        rebuildAnthropicClient()
        resetAPICheckState()
    }

    private var cachedToken: String?

    func rebuildAnthropicClient() {
        guard let token = cachedToken,
              !token.isEmpty,
              !dangerousZoneBaseURL.isEmpty,
              AnthropicClient.isValidBaseURL(dangerousZoneBaseURL)
        else {
            anthropicClient = nil
            return
        }
        anthropicClient = AnthropicClient(
            baseURL: dangerousZoneBaseURL,
            authToken: token,
            model: dangerousZoneModel.isEmpty ? AnthropicClient.defaultModel : dangerousZoneModel
        )
    }

    /// Load token from Keychain into cache. Only reads Keychain if not already cached.
    private func loadTokenFromKeychain() {
        guard cachedToken == nil else { return }
        cachedToken = KeychainHelper.loadToken()
        dangerousZoneTokenIsSet = cachedToken != nil
    }

    /// Called when switching to Cloud API or on launch with Cloud API selected.
    /// Reads Keychain lazily, builds client, auto-checks if credentials exist.
    func ensureCloudAPIReady() {
        loadTokenFromKeychain()
        rebuildAnthropicClient()
        if dangerousZoneTokenIsSet && !dangerousZoneBaseURL.isEmpty {
            log("Cloud API: credentials found, auto-checking...")
            performAPICheck()
        } else {
            log("Cloud API: no credentials configured")
        }
    }

    func resetAPICheckState() {
        apiCheckState = .unchecked
    }

    func performAPICheck() {
        rebuildAnthropicClient()
        guard let client = anthropicClient else {
            apiCheckState = .invalid(message: "Missing credentials or invalid URL")
            return
        }
        apiCheckState = .checking
        log("API credential check: testing connection to \(client.baseURL) (model: \(client.model))...")
        client.checkAPI { [weak self] result in
            guard let self else { return }
            self.apiCheckState = result
            switch result {
            case .valid(let ms):
                self.log("API credential check: passed, latency \(ms)ms — Cloud API revise active")
            case .invalid(let msg):
                self.log("API credential check: failed — \(msg)")
            default:
                break
            }
        }
    }

    // MARK: - VAD Streaming (Silence-Triggered Full-Audio Inference)

    private var vadState: VADState = .idle
    private var vadSilenceStart: Date?
    private var vadIsInferring = false
    private var vadFallbackTimer: Timer?
    private var vadLastSampleCount: Int = 0  // track if new audio since last inference
    private var vadGlobalPastedText: String = ""  // text currently typed at cursor in target app
    private let vadCursorSymbol = " ...▍"

    private enum VADState {
        case idle
        case speaking
        case maybeSilent
    }

    private let vadSilenceThreshold: Float = 0.05
    private let vadSilenceDuration: TimeInterval = 0.5
    private let vadMaxChunkDuration: TimeInterval = 5.0
    private let vadMinSamples: Int = 16000  // need at least 1s for useful output

    private func vadProcessAudioLevel(_ level: Float) {
        guard isRecording, sttEngine == .whisper else { return }

        switch vadState {
        case .idle:
            break
        case .speaking:
            if level < vadSilenceThreshold {
                vadState = .maybeSilent
                vadSilenceStart = Date()
            }
        case .maybeSilent:
            if level >= vadSilenceThreshold {
                vadState = .speaking
                vadSilenceStart = nil
            } else if let start = vadSilenceStart,
                      Date().timeIntervalSince(start) >= vadSilenceDuration {
                vadState = .speaking
                vadSilenceStart = nil
                vadTriggerInference()
            }
        }
    }

    private func vadTriggerInference() {
        let snapshot = audioRecorder.accumulatedSamples
        guard snapshot.count >= vadMinSamples else { return }
        guard snapshot.count > vadLastSampleCount else { return }  // no new audio
        guard !vadIsInferring else { return }

        vadIsInferring = true
        vadLastSampleCount = snapshot.count

        vadFallbackTimer?.invalidate()
        vadFallbackTimer = nil

        log("VAD: inference triggered (\(snapshot.count) samples, \(String(format: "%.1f", Double(snapshot.count) / 16000))s)")

        let normalized = normalizeAudio(snapshot)
        whisperBridge.transcribe(samples: normalized, language: "auto") { [weak self] text in
            guard let self else { return }
            self.vadIsInferring = false
            guard self.isRecording else { return }

            let display = self.convertScript(text)
            self.transcriptionText = display
            self.log("VAD: partial result (\(text.count) chars)")

            // Incremental typing for global hotkey
            if self.isGlobalHotkeyActive && GlobalHotkeyManager.isAccessibilityGranted {
                self.vadIncrementalPaste(newText: display)
            }

            self.startVADFallbackTimer()
        }
    }

    private func startVADFallbackTimer() {
        vadFallbackTimer?.invalidate()
        vadFallbackTimer = Timer.scheduledTimer(withTimeInterval: vadMaxChunkDuration, repeats: false) { [weak self] _ in
            guard let self, self.isRecording else { return }
            self.log("VAD: fallback — 5s continuous speech, triggering inference")
            self.vadTriggerInference()
        }
    }

    private func vadStartRecording() {
        vadState = .speaking
        vadSilenceStart = nil
        vadLastSampleCount = 0
        vadIsInferring = false
        vadGlobalPastedText = ""
        transcriptionText = ""
        startVADFallbackTimer()
    }

    private func vadStopRecording() {
        vadFallbackTimer?.invalidate()
        vadFallbackTimer = nil
        vadState = .idle
        vadSilenceStart = nil
    }

    /// Incrementally type text at cursor in target app during global hotkey recording.
    /// Computes diff with previously typed text, backspaces the changed suffix, types the new suffix.
    /// Appends a cursor symbol (▍) at the end to indicate "still processing".
    private func vadIncrementalPaste(newText: String) {
        let newWithCursor = newText + vadCursorSymbol
        let old = vadGlobalPastedText

        // Find common prefix length
        let commonLen = zip(old, newWithCursor).prefix(while: { $0 == $1 }).count
        let deleteCount = old.count - commonLen
        let addText = String(newWithCursor.dropFirst(commonLen))

        if deleteCount > 0 {
            GlobalHotkeyManager.pressBackspace(count: deleteCount)
        }
        if !addText.isEmpty {
            GlobalHotkeyManager.typeText(addText)
        }

        vadGlobalPastedText = newWithCursor
        log("VAD global: incremental paste (del \(deleteCount), add \(addText.count), total \(newWithCursor.count) chars)")
    }

    private var reviseFailedTimer: DispatchWorkItem?
    private func showReviseFailed() {
        reviseFailedTimer?.cancel()
        withAnimation { reviseFailed = true }
        let item = DispatchWorkItem { [weak self] in
            withAnimation { self?.reviseFailed = false }
        }
        reviseFailedTimer = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 4, execute: item)
    }

    private var lowAudioWarningTimer: DispatchWorkItem?
    private func showLowAudioWarning() {
        lowAudioWarningTimer?.cancel()
        withAnimation { lowAudioWarning = true }
        let item = DispatchWorkItem { [weak self] in
            withAnimation { self?.lowAudioWarning = false }
        }
        lowAudioWarningTimer = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 4, execute: item)
    }

    private var reviseFailedFallbackTimer: DispatchWorkItem?
    private func showReviseFailedWithFallback() {
        reviseFailedFallbackTimer?.cancel()
        withAnimation { reviseFailedWithFallback = true }
        let item = DispatchWorkItem { [weak self] in
            withAnimation { self?.reviseFailedWithFallback = false }
        }
        reviseFailedFallbackTimer = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 4, execute: item)
    }

    // MARK: - Punctuation Model Download/Delete

    func downloadPunctuationModel() {
        guard !isDownloadingPunctuationModel else { return }
        isDownloadingPunctuationModel = true
        punctuationModelDownloadProgress = 0
        log("BERT punctuation model: starting download from \(PunctuationRestorer.downloadURL)")

        let session = URLSession(configuration: .default, delegate: nil, delegateQueue: nil)
        let task = session.downloadTask(with: PunctuationRestorer.downloadURL) { [weak self] tmpURL, response, error in
            session.finishTasksAndInvalidate()
            DispatchQueue.main.async {
                guard let self else { return }
                guard let tmpURL, error == nil else {
                    let msg = error?.localizedDescription ?? "Unknown download error"
                    self.log("BERT punctuation model: download failed — \(msg)")
                    self.isDownloadingPunctuationModel = false
                    return
                }
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                    let msg = "HTTP \(httpResponse.statusCode)"
                    self.log("BERT punctuation model: download failed — \(msg)")
                    self.isDownloadingPunctuationModel = false
                    try? FileManager.default.removeItem(at: tmpURL)
                    return
                }
                self.log("BERT punctuation model: download complete, extracting...")
                self.extractPunctuationModel(zipURL: tmpURL)
            }
        }

        let observation = task.progress.observe(\.fractionCompleted) { [weak self] progress, _ in
            DispatchQueue.main.async {
                self?.punctuationModelDownloadProgress = progress.fractionCompleted
            }
        }
        objc_setAssociatedObject(task, "progressObservation", observation, .OBJC_ASSOCIATION_RETAIN)

        task.resume()
    }

    private func extractPunctuationModel(zipURL: URL) {
        let destDir = Self.modelDirectory

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            try? FileManager.default.createDirectory(at: destDir, withIntermediateDirectories: true)

            // Remove existing model if any
            let modelPath = PunctuationRestorer.modelPath
            if FileManager.default.fileExists(atPath: modelPath.path) {
                try? FileManager.default.removeItem(at: modelPath)
            }

            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
            process.arguments = ["-xk", zipURL.path, destDir.path]

            do {
                try process.run()
                process.waitUntilExit()

                DispatchQueue.main.async {
                    guard let self else { return }
                    self.isDownloadingPunctuationModel = false

                    if process.terminationStatus == 0 && FileManager.default.fileExists(atPath: modelPath.path) {
                        self.log("BERT punctuation model: extracted successfully")
                        self.loadPunctuationModelIfAvailable()
                    } else {
                        self.log("BERT punctuation model: extraction failed (exit code \(process.terminationStatus))")
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    guard let self else { return }
                    self.isDownloadingPunctuationModel = false
                    self.log("BERT punctuation model: extraction error — \(error.localizedDescription)")
                }
            }

            try? FileManager.default.removeItem(at: zipURL)
        }
    }

    func deletePunctuationModel() {
        let modelPath = PunctuationRestorer.modelPath
        do {
            try FileManager.default.removeItem(at: modelPath)
            log("BERT punctuation model: deleted from \(modelPath.path)")
        } catch {
            log("BERT punctuation model: delete error — \(error.localizedDescription)")
        }
        punctuationRestorer.unloadModel()
        isPunctuationModelLoaded = false
        usePunctuationRestore = false
    }

    // MARK: - Model Management

    static var modelDirectory: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("Voice2Text", isDirectory: true)
    }

    func modelPath(for model: WhisperModel) -> URL {
        Self.modelDirectory.appendingPathComponent(model.fileName)
    }

    func isModelDownloaded(_ model: WhisperModel) -> Bool {
        FileManager.default.fileExists(atPath: modelPath(for: model).path)
    }

    func deleteModel(_ model: WhisperModel) {
        // Block delete if this model is being downloaded
        guard !isDownloadingModel else { return }
        let path = modelPath(for: model)
        try? FileManager.default.removeItem(at: path)
        if model == selectedModel {
            isModelLoaded = false
            loadedModelName = ""
        }
    }

    func loadModelIfAvailable() {
        let path = modelPath(for: selectedModel)
        guard FileManager.default.fileExists(atPath: path.path) else {
            isModelLoaded = false
            loadedModelName = ""
            log("Whisper model \(selectedModel.rawValue) not found at \(path.path), skipping load")
            return
        }
        isModelLoaded = false
        loadedModelName = ""
        log("Whisper: loading model \(selectedModel.rawValue) from disk...")
        let model = selectedModel
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            let success = self.whisperBridge.loadModel(path: path.path)
            DispatchQueue.main.async {
                self.isModelLoaded = success
                self.loadedModelName = success ? model.displayName : ""
                if success {
                    self.log("Whisper: model \(model.rawValue) loaded successfully")
                } else {
                    self.log("Whisper: model \(model.rawValue) failed to load — deleting corrupt file")
                    try? FileManager.default.removeItem(at: path)
                }
            }
        }
    }

    func switchModel(to model: WhisperModel) {
        let prev = selectedModel.displayName
        selectedModel = model
        UserDefaults.standard.set(model.rawValue, forKey: "selectedModel")
        log("Switch model: \(prev) → \(model.displayName), downloaded=\(isModelDownloaded(model))")
        if isModelDownloaded(model) {
            loadModelIfAvailable()
        } else {
            isModelLoaded = false
            loadedModelName = ""
        }
    }

    func downloadModel(_ model: WhisperModel) {
        guard !isDownloadingModel else { return }
        isDownloadingModel = true
        downloadProgress = 0

        let destDir = Self.modelDirectory
        let destPath = modelPath(for: model)

        try? FileManager.default.createDirectory(at: destDir, withIntermediateDirectories: true)

        let session = URLSession(configuration: .default, delegate: nil, delegateQueue: nil)
        let task = session.downloadTask(with: model.downloadURL) { [weak self] tmpURL, _, error in
            session.finishTasksAndInvalidate()
            DispatchQueue.main.async {
                guard let self else { return }
                self.isDownloadingModel = false

                guard let tmpURL, error == nil else {
                    print("Model download failed: \(error?.localizedDescription ?? "unknown")")
                    return
                }

                do {
                    if FileManager.default.fileExists(atPath: destPath.path) {
                        try FileManager.default.removeItem(at: destPath)
                    }
                    try FileManager.default.moveItem(at: tmpURL, to: destPath)
                    if self.selectedModel == model {
                        self.loadModelIfAvailable()
                    }
                } catch {
                    print("Failed to save model: \(error.localizedDescription)")
                }
            }
        }

        let observation = task.progress.observe(\.fractionCompleted) { [weak self] progress, _ in
            DispatchQueue.main.async {
                self?.downloadProgress = progress.fractionCompleted
            }
        }
        objc_setAssociatedObject(task, "progressObservation", observation, .OBJC_ASSOCIATION_RETAIN)

        task.resume()
    }

    // MARK: - Local LLM Model Management

    /// Load the selected Local LLM model on startup if downloaded and Local LLM provider is selected.
    private func loadLocalLLMModelIfAvailable() {
        guard postEditProvider == .localLLM,
              isLocalLLMModelDownloaded(selectedLocalLLMModel) else { return }
        log("Local LLM: auto-loading \(selectedLocalLLMModel.displayName) on startup")
        validateAndLoadLocalLLMModel(selectedLocalLLMModel)
    }

    func localLLMModelPath(for model: LocalLLMModel) -> URL {
        Self.modelDirectory.appendingPathComponent(model.fileName)
    }

    func isLocalLLMModelDownloaded(_ model: LocalLLMModel) -> Bool {
        FileManager.default.fileExists(atPath: localLLMModelPath(for: model).path)
    }

    var isAnyLocalLLMModelDownloaded: Bool {
        LocalLLMModel.allCases.contains { isLocalLLMModelDownloaded($0) }
    }

    func deleteLocalLLMModel(_ model: LocalLLMModel) {
        // Block delete if this model is being downloaded or loaded
        if isDownloadingLocalLLM && downloadingLocalLLMModel == model { return }
        if model == selectedLocalLLMModel && isLoadingLocalLLMModel { return }
        let path = localLLMModelPath(for: model)
        if model == selectedLocalLLMModel && isLocalLLMModelLoaded {
            log("Local LLM: unloading \(model.displayName) before delete")
            isLocalLLMModelLoaded = false
            llamaBridge.freeModelAsync { [weak self] in
                do {
                    try FileManager.default.removeItem(at: path)
                    self?.log("Local LLM: deleted \(model.displayName)")
                } catch {
                    self?.log("Local LLM: delete error — \(error.localizedDescription)")
                }
            }
        } else {
            do {
                try FileManager.default.removeItem(at: path)
                log("Local LLM: deleted \(model.displayName) from \(path.path)")
            } catch {
                log("Local LLM: delete error — \(error.localizedDescription)")
            }
        }
    }

    /// Public entry point to load the currently selected Local LLM model (e.g., from badge tap).
    func loadLocalLLMModel() {
        guard isLocalLLMModelDownloaded(selectedLocalLLMModel) else { return }
        validateAndLoadLocalLLMModel(selectedLocalLLMModel)
    }

    func selectLocalLLMModel(_ model: LocalLLMModel) {
        guard !isLoadingLocalLLMModel else {
            log("Local LLM: model load in progress, cannot switch now")
            return
        }
        let oldModel = selectedLocalLLMModel
        selectedLocalLLMModel = model
        if oldModel != model && isLocalLLMModelLoaded {
            log("Local LLM: unloading \(oldModel.displayName), switching to \(model.displayName)")
            isLocalLLMModelLoaded = false
            llamaBridge.freeModelAsync()
        }
    }

    func downloadLocalLLMModel(_ model: LocalLLMModel) {
        guard !isDownloadingLocalLLM else { return }
        isDownloadingLocalLLM = true
        downloadingLocalLLMModel = model
        localLLMDownloadProgress = 0
        log("Local LLM: starting download of \(model.displayName) from \(model.downloadURL)")

        let destDir = Self.modelDirectory
        let destPath = localLLMModelPath(for: model)

        try? FileManager.default.createDirectory(at: destDir, withIntermediateDirectories: true)

        let session = URLSession(configuration: .default, delegate: nil, delegateQueue: nil)
        let task = session.downloadTask(with: model.downloadURL) { [weak self] tmpURL, _, error in
            session.finishTasksAndInvalidate()
            DispatchQueue.main.async {
                guard let self else { return }
                self.isDownloadingLocalLLM = false
                self.downloadingLocalLLMModel = nil
                self.localLLMDownloadTask = nil

                guard let tmpURL, error == nil else {
                    let isCancelled = (error as? URLError)?.code == .cancelled
                    if isCancelled {
                        self.log("Local LLM: download cancelled")
                    } else {
                        self.log("Local LLM: download failed — \(error?.localizedDescription ?? "unknown")")
                    }
                    return
                }

                do {
                    if FileManager.default.fileExists(atPath: destPath.path) {
                        try FileManager.default.removeItem(at: destPath)
                    }
                    try FileManager.default.moveItem(at: tmpURL, to: destPath)
                    self.log("Local LLM: \(model.displayName) downloaded successfully")
                    // Only auto-load if still on Local LLM provider and this is the selected model
                    if self.postEditProvider == .localLLM && self.selectedLocalLLMModel == model {
                        self.log("Local LLM: auto-loading \(model.displayName) after download")
                        self.validateAndLoadLocalLLMModel(model)
                    }
                } catch {
                    self.log("Local LLM: failed to save model — \(error.localizedDescription)")
                }
            }
        }

        let observation = task.progress.observe(\.fractionCompleted) { [weak self] progress, _ in
            DispatchQueue.main.async {
                self?.localLLMDownloadProgress = progress.fractionCompleted
            }
        }
        objc_setAssociatedObject(task, "progressObservation", observation, .OBJC_ASSOCIATION_RETAIN)

        localLLMDownloadTask = task
        task.resume()
    }

    func cancelLocalLLMDownload() {
        guard isDownloadingLocalLLM else { return }
        log("Local LLM: cancelling download of \(downloadingLocalLLMModel?.displayName ?? "unknown")")
        localLLMDownloadTask?.cancel()
    }

    /// Attempt to load a Local LLM model; if load fails, delete the corrupt file.
    private func validateAndLoadLocalLLMModel(_ model: LocalLLMModel) {
        guard !isLoadingLocalLLMModel else {
            log("Local LLM: load already in progress, ignoring")
            return
        }
        isLoadingLocalLLMModel = true
        let path = localLLMModelPath(for: model).path
        llamaBridge.loadModel(path: path) { [weak self] success in
            guard let self else { return }
            self.isLoadingLocalLLMModel = false
            // Check that provider/model hasn't changed while loading
            guard self.postEditProvider == .localLLM,
                  self.selectedLocalLLMModel == model else {
                self.log("Local LLM: provider or model changed during load, discarding result")
                if success { self.llamaBridge.freeModelAsync() }
                return
            }
            if success {
                self.isLocalLLMModelLoaded = true
                self.log("Local LLM: \(model.displayName) loaded and validated")
            } else {
                self.log("Local LLM: \(model.displayName) failed to load — deleting corrupt file")
                self.isLocalLLMModelLoaded = false
                try? FileManager.default.removeItem(atPath: path)
            }
        }
    }

    // MARK: - Global Hotkey

    func setupGlobalHotkey() {
        let manager = GlobalHotkeyManager.shared

        manager.onHotkeyDown = { [weak self] in
            self?.globalHotkeyDown()
        }
        manager.onHotkeyUp = { [weak self] in
            self?.globalHotkeyUp()
        }

        if globalHotkeyEnabled {
            manager.register()
            log("Global hotkey registered: \(manager.combo.displayString)")
        }
    }

    func globalHotkeyDown() {
        guard globalHotkeyEnabled, canToggle, !isRecording else { return }
        isGlobalHotkeyActive = true
        FloatingRecordingPanel.shared.show(state: .recording)
        toggleRecording()
        log("Global hotkey: key down → started recording (will auto-paste on release)")
    }

    func globalHotkeyUp() {
        guard isGlobalHotkeyActive, isRecording else { return }
        FloatingRecordingPanel.shared.show(state: .transcribing)
        toggleRecording()
        log("Global hotkey: key up → stopped recording, transcribing...")
    }

    func performAutoPaste(_ text: String) {
        guard isGlobalHotkeyActive else { return }
        isGlobalHotkeyActive = false

        // Clear streaming text typed during recording
        let streamingText = vadGlobalPastedText
        vadGlobalPastedText = ""

        guard !text.isEmpty else {
            if !streamingText.isEmpty {
                GlobalHotkeyManager.pressBackspace(count: streamingText.count)
            }
            FloatingRecordingPanel.shared.hide()
            return
        }

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        log("Global hotkey: result copied to clipboard (\(text.count) chars)")

        if GlobalHotkeyManager.isAccessibilityGranted {
            if !streamingText.isEmpty {
                // Delete streaming text, then paste final result
                GlobalHotkeyManager.pressBackspace(count: streamingText.count)
                log("Global hotkey: cleared \(streamingText.count) streaming chars")
            }
            // Small delay to ensure backspaces are processed before paste
            let delay = streamingText.isEmpty ? 0.05 : 0.1
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                GlobalHotkeyManager.pasteFromClipboard()
                FloatingRecordingPanel.shared.showDoneAndHide()
                self.log("Global hotkey: auto-pasted via ⌘V to frontmost app")
                self.scheduleClipboardClear()
            }
        } else {
            FloatingRecordingPanel.shared.showDoneAndHide()
            log("Global hotkey: accessibility permission not granted, text in clipboard but cannot auto-paste")
        }
    }

    /// Clear clipboard after a short delay post-paste to reduce exposure window.
    private var clipboardClearTimer: DispatchWorkItem?
    private func scheduleClipboardClear() {
        clipboardClearTimer?.cancel()
        let item = DispatchWorkItem { [weak self] in
            // Only clear if clipboard still contains our text
            if let current = NSPasteboard.general.string(forType: .string),
               current == self?.transcriptionText {
                NSPasteboard.general.clearContents()
                self?.log("Clipboard auto-cleared after 30s (security: remove transcription from clipboard)")
            }
        }
        clipboardClearTimer = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 30, execute: item)
    }

    func refreshAccessibilityStatus() {
        isAccessibilityGranted = GlobalHotkeyManager.isAccessibilityGranted
        if isAccessibilityGranted {
            accessibilityWasGranted = true
        }
    }

    // MARK: - Permission Checks on Launch

    func checkPermissionsOnLaunch() {
        guard onboardingCompleted else { return }

        // Check microphone permission
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            isMicrophoneGranted = true
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
                DispatchQueue.main.async {
                    self?.isMicrophoneGranted = granted
                    if !granted {
                        self?.showMicrophoneAlert = true
                    }
                }
            }
        case .denied, .restricted:
            isMicrophoneGranted = false
            showMicrophoneAlert = true
        @unknown default:
            break
        }

        // Check accessibility (only if global hotkey is enabled)
        refreshAccessibilityStatus()
        if globalHotkeyEnabled && !isAccessibilityGranted {
            if accessibilityWasGranted {
                // Previously granted but now invalid — likely app was upgraded
                showAccessibilityUpgradeAlert = true
            } else {
                showAccessibilityAlert = true
            }
        }
    }
}
