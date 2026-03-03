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
    @Published var useLLMReformat = false
    @Published var isLLMAvailable = false
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
    @Published var usePunctuationRestore = false
    @Published var isPunctuationServerAvailable = false
    @Published var audioLevel: Float = 0
    @Published var devMode = false
    @Published var debugLog: [String] = []
    @AppStorage("showFirstUseTooltip") var showFirstUseTooltip = true
    @AppStorage("onboardingCompleted") var onboardingCompleted = false
    @AppStorage("globalHotkeyEnabled") var globalHotkeyEnabled = true
    @AppStorage("accessibilityWasGranted") var accessibilityWasGranted = false
    @Published var isAccessibilityGranted = false
    @Published var isGlobalHotkeyActive = false
    @Published var showMicrophoneAlert = false
    @Published var showAccessibilityAlert = false
    @Published var showAccessibilityUpgradeAlert = false
    @Published var isMicrophoneGranted = false

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

    func log(_ message: String) {
        guard devMode else { return }
        let ts = Self.dateFormatter.string(from: Date())
        debugLog.append("[\(ts)] \(message)")
        // Keep last 200 lines
        if debugLog.count > 200 { debugLog.removeFirst(debugLog.count - 200) }
    }

    private init() {
        anthropicClient = AnthropicClient.fromEnvironment()
        isLLMAvailable = anthropicClient != nil
        useLLMReformat = false
        log("LLM reformat: disabled (feature greyed out)")

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
                self?.isNetworkAvailable = path.status == .satisfied
            }
        }
        networkMonitor.start(queue: DispatchQueue(label: "com.voice2text.network"))

        loadModelIfAvailable()
        setupKeyboardShortcuts()
        checkPunctuationServer()
        setupGlobalHotkey()
        refreshAccessibilityStatus()
        // Delay permission checks to allow SwiftUI view to be ready for alerts
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.checkPermissionsOnLaunch()
        }
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

        log("Recorded \(samples.count) samples (\(String(format: "%.1f", Double(samples.count) / 16000))s)")
        isTranscribing = true
        transcribe(samples: samples, language: "auto")
    }

    // MARK: - Apple Speech

    private func startAppleSpeech() {
        isStarting = true
        appleSpeech.requestPermission { [weak self] granted in
            guard let self, granted else {
                self?.isStarting = false
                self?.log("Apple Speech: permission denied")
                return
            }
            self.transcriptionText = ""
            self.appleSpeechRequest = self.appleSpeech.startRecognition(
                onResult: { [weak self] text, isFinal in
                    self?.transcriptionText = self?.convertScript(text) ?? text
                    if isFinal {
                        self?.rawTranscription = text
                        self?.log("Apple Speech: final result (\(text.count) chars)")
                    }
                },
                onError: { [weak self] error in
                    self?.log("Apple Speech error: \(error)")
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
                self?.log("Apple Speech: recording started = \(success)")
            }
        }
    }

    private func stopAppleSpeech() {
        audioRecorder.stopRecording()
        appleSpeech.stopRecognition()
        appleSpeechRequest = nil
        isRecording = false
        audioLevel = 0
        rawTranscription = transcriptionText
        log("Apple Speech: stopped")
        performAutoPaste(transcriptionText)
    }

    private func transcribe(samples: [Float], language: String) {
        log("Whisper inference started (language=\(language))")
        whisperBridge.transcribe(samples: samples, language: language) { [weak self] text in
            guard let self else { return }
            self.log("Whisper result: \(text.count) chars")

            // If auto-detected and result contains non-Chinese/English text, retry with "zh"
            if language == "auto" && self.containsUnexpectedLanguage(text) {
                self.log("Unexpected language detected, retrying with language=zh")
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

    // MARK: - Punctuation Restore

    func checkPunctuationServer() {
        PunctuationClient.shared.checkHealth { [weak self] ok in
            guard let self else { return }
            if ok {
                self.isPunctuationServerAvailable = true
                self.usePunctuationRestore = true
                self.log("Punctuation server: available, enabled by default")
            } else {
                self.log("Punctuation server: unavailable, attempting auto-launch...")
                self.autoLaunchPunctuationServer()
            }
        }
    }

    /// Try to launch PunctuationServer.app, then poll health until ready.
    private func autoLaunchPunctuationServer() {
        guard PunctuationClient.launchServer() else {
            log("Punctuation server: .app not found in known locations")
            isPunctuationServerAvailable = false
            usePunctuationRestore = false
            return
        }
        log("Punctuation server: launch attempted, waiting for startup...")

        // Poll health every 2s, up to 60s (model download on first run can be slow)
        let maxAttempts = 30
        var attempt = 0
        func poll() {
            attempt += 1
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
                guard let self else { return }
                PunctuationClient.shared.checkHealth { [weak self] ok in
                    guard let self else { return }
                    if ok {
                        self.isPunctuationServerAvailable = true
                        self.usePunctuationRestore = true
                        self.log("Punctuation server: ready after \(attempt * 2)s")
                    } else if attempt < maxAttempts {
                        poll()
                    } else {
                        self.isPunctuationServerAvailable = false
                        self.usePunctuationRestore = false
                        self.log("Punctuation server: failed to start after \(maxAttempts * 2)s")
                    }
                }
            }
        }
        poll()
    }

    /// Post-process whisper output: punctuation restore → LLM reformat → script conversion.
    private func postProcess(_ text: String) {
        isReformatting = true

        if usePunctuationRestore && isPunctuationServerAvailable && textContainsChinese(text) {
            log("Punctuation restore: sending \(text.count) chars...")
            PunctuationClient.shared.restore(text) { [weak self] restored, error in
                guard let self else { return }
                if let restored {
                    self.log("Punctuation restore: success (\(restored.count) chars)")
                    self.rawTranscription = restored
                    self.applyLLMAndConvert(restored)
                } else {
                    self.log("Punctuation restore failed: \(error ?? "unknown"). Passing through.")
                    self.applyLLMAndConvert(text)
                }
            }
        } else {
            applyLLMAndConvert(text)
        }
    }

    /// Apply LLM reformat (if enabled) then script conversion.
    private func applyLLMAndConvert(_ text: String) {
        if useLLMReformat, let client = anthropicClient {
            log("LLM reformat: sending to Claude...")
            client.reformatText(text) { [weak self] result, error in
                DispatchQueue.main.async {
                    guard let self else { return }
                    if let result {
                        self.log("LLM reformat: success (\(result.count) chars)")
                        self.transcriptionText = self.convertScript(result)
                    } else {
                        self.log("LLM reformat failed: \(error ?? "unknown error"). Falling back.")
                        self.isLLMAvailable = false
                        self.useLLMReformat = false
                        self.transcriptionText = self.convertScript(text)
                    }
                    self.isReformatting = false
                    self.performAutoPaste(self.transcriptionText)
                }
            }
        } else {
            transcriptionText = convertScript(text)
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
            log("Model \(selectedModel.rawValue) not found at \(path.path)")
            return
        }
        isModelLoaded = false
        loadedModelName = ""
        log("Loading model \(selectedModel.rawValue)...")
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            let success = self.whisperBridge.loadModel(path: path.path)
            DispatchQueue.main.async {
                self.isModelLoaded = success
                self.loadedModelName = success ? self.selectedModel.displayName : ""
                self.log(success ? "Model \(self.selectedModel.rawValue) loaded" : "Model \(self.selectedModel.rawValue) failed to load")
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
        log("Global hotkey: started recording")
    }

    func globalHotkeyUp() {
        guard isGlobalHotkeyActive, isRecording else { return }
        FloatingRecordingPanel.shared.show(state: .transcribing)
        toggleRecording()
        log("Global hotkey: stopped recording, transcribing...")
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
        log("Global hotkey: copied to clipboard (\(text.count) chars)")

        if GlobalHotkeyManager.isAccessibilityGranted {
            // Small delay to ensure clipboard is ready
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                GlobalHotkeyManager.pasteFromClipboard()
                FloatingRecordingPanel.shared.showDoneAndHide()
                self.log("Global hotkey: auto-pasted")
            }
        } else {
            FloatingRecordingPanel.shared.showDoneAndHide()
            log("Global hotkey: accessibility not granted, skipping auto-paste")
        }
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
