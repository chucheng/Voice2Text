import Foundation

final class WhisperBridge {
    private var ctx: OpaquePointer?
    private let inferenceQueue = DispatchQueue(label: "com.voice2text.whisper", qos: .userInitiated)

    /// Load a whisper model from file path. Call from background thread for large models.
    func loadModel(path: String) -> Bool {
        if ctx != nil {
            whisper_free(ctx)
            ctx = nil
        }
        var params = whisper_context_default_params()
        params.use_gpu = true
        params.flash_attn = false
        ctx = whisper_init_from_file_with_params(path, params)
        return ctx != nil
    }

    /// Transcribe audio samples (16kHz mono Float32).
    /// - Parameters:
    ///   - samples: PCM Float32 audio at 16kHz
    ///   - language: "zh" for Chinese, "en" for English, or "auto" for auto-detect
    ///   - completion: Called on main thread with transcribed text (empty string on failure)
    /// Allowed language codes for whisper inference.
    private static let allowedLanguages: Set<String> = [
        "auto", "zh", "en", "ja", "ko", "de", "fr", "es", "pt", "ru", "it", "nl",
        "pl", "tr", "sv", "da", "fi", "no", "hu", "cs", "ro", "bg", "el", "hr",
        "sk", "sl", "lt", "lv", "et", "mt", "sq", "mk", "sr", "bs", "uk", "be",
        "ca", "gl", "eu", "af", "cy", "ga", "gd", "is", "lb", "ms", "id", "tl",
        "vi", "th", "hi", "bn", "ta", "te", "mr", "ur", "ne", "si", "km", "lo",
        "my", "ka", "am", "sw", "yo", "ig", "ha", "so", "ar", "he", "fa", "ps",
        "az", "uz", "kk", "ky", "tg", "tk", "mn", "bo", "jw", "su", "ht", "mg",
        "oc", "br", "as", "nn", "ml", "kn", "gu", "pa", "or", "sa", "tt", "ba",
        "sn", "ln", "fo", "mi", "yi", "la", "haw", "sd", "ug", "tk"
    ]

    func transcribe(samples: [Float], language: String, completion: @escaping (String) -> Void) {
        guard let ctx else {
            DispatchQueue.main.async { completion("") }
            return
        }

        // Security: validate language against allowlist before passing to C layer
        let safeLanguage = Self.allowedLanguages.contains(language) ? language : "auto"

        inferenceQueue.async {
            var params = whisper_full_default_params(WHISPER_SAMPLING_GREEDY)
            params.print_realtime = false
            params.print_progress = false
            params.print_special = false
            params.print_timestamps = false
            params.translate = false
            params.single_segment = false
            params.no_timestamps = true
            params.n_threads = max(1, Int32(ProcessInfo.processInfo.activeProcessorCount - 1))

            let result = safeLanguage.withCString { langPtr in
                params.language = langPtr
                return samples.withUnsafeBufferPointer { buf in
                    whisper_full(ctx, params, buf.baseAddress, Int32(buf.count))
                }
            }

            var text = ""
            if result == 0 {
                let nSegments = whisper_full_n_segments(ctx)
                for i in 0..<nSegments {
                    if let segText = whisper_full_get_segment_text(ctx, i) {
                        text += String(cString: segText)
                    }
                }
            }

            DispatchQueue.main.async { completion(text.trimmingCharacters(in: .whitespacesAndNewlines)) }
        }
    }

    /// Explicitly free the model before app termination.
    /// Dispatches synchronously on inferenceQueue to avoid
    /// racing with in-flight transcription.
    func freeModelSync() {
        inferenceQueue.sync {
            if ctx != nil {
                whisper_free(ctx)
                ctx = nil
            }
        }
    }

    deinit {
        if ctx != nil {
            whisper_free(ctx)
            ctx = nil
        }
    }
}
