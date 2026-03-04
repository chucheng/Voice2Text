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
    @Published var usePostEditRevise = false
    /// When true, auto-enable revise after API check succeeds.
    var pendingEnableRevise = false
    @Published var reviseFailed = false
    @Published var reviseFailedWithFallback = false
    @Published var customRevisePrompt: String = {
        let stored = UserDefaults.standard.string(forKey: "customRevisePrompt")
        // Migrate: empty string from previous versions means "use default"
        return (stored == nil || stored!.isEmpty) ? AnthropicClient.revisePrompt : stored!
    }() {
        didSet { UserDefaults.standard.set(customRevisePrompt, forKey: "customRevisePrompt") }
    }

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

    /// Weak reference to the main window, captured by WindowAccessor.
    /// Used by AppDelegate to reopen the window on Dock icon click.
    weak var mainWindow: NSWindow?

    let audioRecorder = AudioRecorder()
    let whisperBridge = WhisperBridge()
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

    /// Always collect logs so history is available when Dev Mode is toggled on.
    /// Whether app is in init phase (logs always recorded during init).
    private var isInitializing = true

    /// Log a debug message. Records when Dev Mode is on or during app init phase.
    func log(_ message: String, force: Bool = false) {
        guard force || devMode || isInitializing else { return }
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

        // Load Dangerous Zone token presence
        dangerousZoneTokenIsSet = KeychainHelper.loadToken() != nil
        rebuildAnthropicClient()
        if let client = anthropicClient {
            log("Post-Edit Revise: client ready (base: \(client.baseURL), model: \(client.model))")
        } else {
            log("Post-Edit Revise: disabled (no API key or base URL configured)")
        }
        if customRevisePrompt != AnthropicClient.revisePrompt {
            log("Post-Edit Revise: using custom prompt (\(customRevisePrompt.count) chars)")
        }

        // Wire audio level callback
        audioRecorder.onAudioLevel = { [weak self] level in
            self?.audioLevel = level
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
        setupKeyboardShortcuts()
        loadPunctuationModelIfAvailable()
        migratePunctuationServer()
        setupGlobalHotkey()
        refreshAccessibilityStatus()
        // Delay permission checks to allow SwiftUI view to be ready for alerts
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.checkPermissionsOnLaunch()
            self?.checkWhatsNew()
        }

        // End init phase — after this, logs only record when Dev Mode is on.
        // Use asyncAfter to allow init-triggered async callbacks (network, punctuation model) to log.
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) { [weak self] in
            self?.isInitializing = false
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
                }
            }
        }
    }

    // MARK: - Whisper

    private func stopAndTranscribe() {
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
        isTranscribing = true
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
        audioRecorder.stopRecording()
        isRecording = false
        audioLevel = 0
        log("Apple Speech: recognition stopped, processing final result...")

        // If Post-Edit Revise is enabled, wait for isFinal before post-processing
        if usePostEditRevise && anthropicClient != nil {
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

    private func transcribe(samples: [Float], language: String) {
        log("Whisper: inference started (language=\(language), model=\(selectedModel.rawValue))")
        whisperBridge.transcribe(samples: samples, language: language) { [weak self] text in
            guard let self else { return }
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
    /// When Post-Edit Revise is enabled, BERT punctuation is skipped (LLM handles it).
    /// On LLM failure, falls back to BERT if available.
    private func postProcess(_ text: String) {
        isReformatting = true

        // When Post-Edit Revise is active, skip BERT — LLM handles punctuation
        if usePostEditRevise, anthropicClient != nil {
            applyLLMAndConvert(text)
        } else if usePunctuationRestore && isPunctuationModelLoaded && textContainsChinese(text) {
            log("BERT punctuation restore: sending \(text.count) chars to CoreML model...")
            punctuationRestorer.restore(text) { [weak self] restored, error in
                guard let self else { return }
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

    /// Apply Post-Edit Revise (if enabled) then script conversion.
    /// On LLM failure, falls back to BERT punctuation model if loaded + Chinese text.
    private func applyLLMAndConvert(_ text: String) {
        if usePostEditRevise, let client = anthropicClient {
            let prompt = (customRevisePrompt == AnthropicClient.revisePrompt) ? nil : customRevisePrompt
            log("Post-Edit Revise: sending \(text.count) chars...")
            log("  → Input: \(text)")
            client.reviseText(text, prompt: prompt) { [weak self] result, error in
                guard let self else { return }
                if let result {
                    self.log("Post-Edit Revise: success (\(result.count) chars)")
                    self.log("  ← Output: \(result)")
                    self.transcriptionText = self.convertScript(result)
                    self.isReformatting = false
                    self.performAutoPaste(self.transcriptionText)
                } else {
                    self.log("Post-Edit Revise failed: \(error ?? "unknown"). Attempting BERT fallback...")
                    self.tryBERTFallback(text)
                }
            }
        } else {
            transcriptionText = convertScript(text)
            isReformatting = false
            performAutoPaste(transcriptionText)
        }
    }

    /// On LLM failure, try BERT punctuation as fallback. If unavailable, use raw text.
    private func tryBERTFallback(_ text: String) {
        if isPunctuationModelLoaded && textContainsChinese(text) {
            log("BERT fallback: sending \(text.count) chars...")
            punctuationRestorer.restore(text) { [weak self] restored, error in
                guard let self else { return }
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
                self.isReformatting = false
                self.performAutoPaste(self.transcriptionText)
            }
        } else {
            log("BERT fallback unavailable. Using raw text.")
            transcriptionText = convertScript(text)
            showReviseFailed()
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
            dangerousZoneTokenIsSet = false
        } else {
            dangerousZoneTokenIsSet = KeychainHelper.saveToken(token)
        }
        rebuildAnthropicClient()
        resetAPICheckState()
    }

    func deleteDangerousZoneToken() {
        KeychainHelper.deleteToken()
        dangerousZoneTokenIsSet = false
        rebuildAnthropicClient()
        resetAPICheckState()
    }

    func rebuildAnthropicClient() {
        guard dangerousZoneTokenIsSet,
              let token = KeychainHelper.loadToken(),
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

    func resetAPICheckState() {
        apiCheckState = .unchecked
        usePostEditRevise = false
        pendingEnableRevise = false
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
                self.log("API credential check: passed, latency \(ms)ms")
                if self.pendingEnableRevise {
                    self.pendingEnableRevise = false
                    self.usePostEditRevise = true
                    self.log("Post-Edit Revise: auto-enabled after API check")
                }
            case .invalid(let msg):
                self.log("API credential check: failed — \(msg)")
                self.pendingEnableRevise = false
                self.usePostEditRevise = false
            default:
                break
            }
        }
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
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            let success = self.whisperBridge.loadModel(path: path.path)
            DispatchQueue.main.async {
                self.isModelLoaded = success
                self.loadedModelName = success ? self.selectedModel.displayName : ""
                self.log(success ? "Whisper: model \(self.selectedModel.rawValue) loaded successfully" : "Whisper: model \(self.selectedModel.rawValue) failed to load")
            }
        }
    }

    func switchModel(to model: WhisperModel) {
        selectedModel = model
        UserDefaults.standard.set(model.rawValue, forKey: "selectedModel")
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

        guard !text.isEmpty else {
            FloatingRecordingPanel.shared.hide()
            return
        }

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        log("Global hotkey: result copied to clipboard (\(text.count) chars)")

        if GlobalHotkeyManager.isAccessibilityGranted {
            // Small delay to ensure clipboard is ready
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                GlobalHotkeyManager.pasteFromClipboard()
                FloatingRecordingPanel.shared.showDoneAndHide()
                self.log("Global hotkey: auto-pasted via ⌘V to frontmost app")
                // Security: clear clipboard after paste to reduce exposure window
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
