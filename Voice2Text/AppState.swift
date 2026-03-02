import Foundation
import AppKit
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
    case simplified = "簡體"

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
    @Published var outputScript: OutputScript = .traditional
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
    @Published var devMode = false
    @Published var debugLog: [String] = []

    private let networkMonitor = NWPathMonitor()

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

        // Monitor network for Apple Speech
        networkMonitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isNetworkAvailable = path.status == .satisfied
            }
        }
        networkMonitor.start(queue: DispatchQueue(label: "com.voice2text.network"))

        loadModelIfAvailable()
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

        guard !samples.isEmpty else {
            transcriptionText = ""
            return
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
        rawTranscription = transcriptionText
        log("Apple Speech: stopped")
    }

    private func transcribe(samples: [Float], language: String) {
        log("Whisper inference started (language=\(language))")
        whisperBridge.transcribe(samples: samples, language: language) { [weak self] text in
            guard let self else { return }
            self.log("Whisper result (\(text.count) chars): \(String(text.prefix(80)))...")

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
    private func containsUnexpectedLanguage(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }

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

    /// Post-process whisper output: LLM reformat (if available) → script conversion.
    private func postProcess(_ text: String) {
        isReformatting = true

        if useLLMReformat, let client = anthropicClient {
            log("LLM reformat: sending to Claude...")
            client.reformatText(text) { [weak self] result, error in
                DispatchQueue.main.async {
                    guard let self else { return }
                    if let result {
                        self.log("LLM reformat: success (\(result.count) chars)")
                        self.transcriptionText = self.convertScript(result)
                    } else {
                        self.log("LLM reformat failed: \(error ?? "unknown error"). Falling back to NLTokenizer.")
                        self.isLLMAvailable = false
                        self.useLLMReformat = false
                        self.transcriptionText = self.convertScript(text)
                    }
                    self.isReformatting = false
                }
            }
        } else {
            transcriptionText = convertScript(text)
            isReformatting = false
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

    func downloadModel() {
        downloadModel(selectedModel)
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
}
