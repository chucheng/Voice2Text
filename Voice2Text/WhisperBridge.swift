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
    func transcribe(samples: [Float], language: String, completion: @escaping (String) -> Void) {
        guard let ctx else {
            DispatchQueue.main.async { completion("") }
            return
        }

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

            let result = language.withCString { langPtr in
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
