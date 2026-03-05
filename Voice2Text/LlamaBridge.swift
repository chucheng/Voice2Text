import Foundation

final class LlamaBridge {
    private var model: OpaquePointer?   // llama_model *
    private var ctx: OpaquePointer?     // llama_context *
    private let inferenceQueue = DispatchQueue(label: "com.voice2text.llama", qos: .userInitiated)

    /// Load a GGUF model from file path.
    func loadModel(path: String, useGPU: Bool = true, completion: @escaping (Bool) -> Void) {
        inferenceQueue.async { [weak self] in
            guard let self else {
                DispatchQueue.main.async { completion(false) }
                return
            }

            // Free previous model if any
            self.freeResources()

            var mparams = llama_model_default_params()
            mparams.n_gpu_layers = useGPU ? -1 : 0  // -1 = offload all layers

            guard let loadedModel = llama_model_load_from_file(path, mparams) else {
                DispatchQueue.main.async { completion(false) }
                return
            }
            self.model = loadedModel

            var cparams = llama_context_default_params()
            cparams.n_ctx = 2048
            cparams.n_batch = 512
            cparams.n_threads = Int32(max(1, ProcessInfo.processInfo.activeProcessorCount - 1))
            cparams.n_threads_batch = cparams.n_threads

            guard let context = llama_init_from_model(loadedModel, cparams) else {
                llama_model_free(loadedModel)
                self.model = nil
                DispatchQueue.main.async { completion(false) }
                return
            }
            self.ctx = context

            DispatchQueue.main.async { completion(true) }
        }
    }

    /// Generate text using the loaded model.
    func generate(text: String, systemPrompt: String, maxTokens: Int = 2048,
                  completion: @escaping (String?) -> Void) {
        inferenceQueue.async { [weak self] in
            guard let self, let model = self.model, let ctx = self.ctx else {
                DispatchQueue.main.async { completion(nil) }
                return
            }

            guard let vocab = llama_model_get_vocab(model) else {
                DispatchQueue.main.async { completion(nil) }
                return
            }

            // Build chat prompt using llama_chat_apply_template
            let prompt = self.buildChatPrompt(systemPrompt: systemPrompt, userMessage: text)

            // Tokenize
            guard let promptTokens = self.tokenize(vocab: vocab, text: prompt, addSpecial: true, parseSpecial: true),
                  !promptTokens.isEmpty else {
                DispatchQueue.main.async { completion(nil) }
                return
            }

            // Check context size
            let nCtx = Int(llama_n_ctx(ctx))
            if promptTokens.count > nCtx - 4 {
                DispatchQueue.main.async { completion(nil) }
                return
            }

            // Clear KV cache
            llama_memory_clear(llama_get_memory(ctx), false)

            // Create sampler chain
            var sparams = llama_sampler_chain_default_params()
            sparams.no_perf = true
            guard let smpl = llama_sampler_chain_init(sparams) else {
                DispatchQueue.main.async { completion(nil) }
                return
            }
            llama_sampler_chain_add(smpl, llama_sampler_init_top_k(40))
            llama_sampler_chain_add(smpl, llama_sampler_init_top_p(0.9, 1))
            llama_sampler_chain_add(smpl, llama_sampler_init_temp(0.3))
            llama_sampler_chain_add(smpl, llama_sampler_init_dist(UInt32.random(in: 0..<UInt32.max)))

            // Decode prompt — use withUnsafeMutableBufferPointer to ensure pointer
            // stays valid through llama_decode (llama_batch_get_one stores the pointer)
            var promptTokensCopy = promptTokens
            var decodeResult: Int32 = -1
            promptTokensCopy.withUnsafeMutableBufferPointer { buf in
                let batch = llama_batch_get_one(buf.baseAddress!, Int32(buf.count))
                decodeResult = llama_decode(ctx, batch)
            }
            if decodeResult != 0 {
                llama_sampler_free(smpl)
                DispatchQueue.main.async { completion(nil) }
                return
            }

            // Generate tokens
            var outputTokens: [llama_token] = []
            let maxGenTokens = min(maxTokens, nCtx - promptTokens.count)

            for _ in 0..<maxGenTokens {
                let newTokenId = llama_sampler_sample(smpl, ctx, -1)

                // Check for end of generation
                if llama_vocab_is_eog(vocab, newTokenId) {
                    break
                }

                outputTokens.append(newTokenId)

                // Decode the new token — withUnsafeMutablePointer ensures pointer
                // stays valid through llama_decode
                var tokenId = newTokenId
                withUnsafeMutablePointer(to: &tokenId) { ptr in
                    let batch = llama_batch_get_one(ptr, 1)
                    decodeResult = llama_decode(ctx, batch)
                }
                if decodeResult != 0 {
                    break
                }
            }

            llama_sampler_free(smpl)

            // Detokenize output
            let result = self.detokenize(vocab: vocab, tokens: outputTokens)
            let trimmed = result.trimmingCharacters(in: .whitespacesAndNewlines)

            DispatchQueue.main.async { completion(trimmed.isEmpty ? nil : trimmed) }
        }
    }

    /// Free model synchronously on the inference queue (safe for app termination).
    /// WARNING: Blocks calling thread. Only use from applicationShouldTerminate.
    func freeModelSync() {
        inferenceQueue.sync {
            freeResources()
        }
    }

    /// Free model asynchronously on the inference queue (safe for UI thread).
    func freeModelAsync(completion: (() -> Void)? = nil) {
        inferenceQueue.async { [weak self] in
            self?.freeResources()
            if let completion {
                DispatchQueue.main.async { completion() }
            }
        }
    }

    var isLoaded: Bool {
        return model != nil && ctx != nil
    }

    // MARK: - Private

    private func freeResources() {
        if ctx != nil {
            llama_free(ctx)
            ctx = nil
        }
        if model != nil {
            llama_model_free(model)
            model = nil
        }
    }

    /// Build a chat prompt string using llama.cpp's built-in chat template support.
    private func buildChatPrompt(systemPrompt: String, userMessage: String) -> String {
        // Use strdup to create stable C strings for the llama_chat_message structs
        let sysRole = strdup("system")!
        let usrRole = strdup("user")!
        let sysContent = strdup(systemPrompt)!
        let usrContent = strdup(userMessage)!

        defer {
            free(sysRole)
            free(usrRole)
            free(sysContent)
            free(usrContent)
        }

        var messages = [
            llama_chat_message(role: sysRole, content: sysContent),
            llama_chat_message(role: usrRole, content: usrContent)
        ]

        // First call to get required buffer size
        let needed = llama_chat_apply_template(nil, &messages, messages.count, true, nil, 0)

        if needed > 0 {
            var buffer = [CChar](repeating: 0, count: Int(needed) + 1)
            let written = llama_chat_apply_template(nil, &messages, messages.count, true, &buffer, Int32(buffer.count))
            if written > 0 {
                return String(cString: buffer)
            }
        }

        // Fallback: manual Qwen Instruct chat format
        return "<|im_start|>system\n\(systemPrompt)<|im_end|>\n<|im_start|>user\n\(userMessage)<|im_end|>\n<|im_start|>assistant\n"
    }

    /// Tokenize text using the model's vocabulary.
    private func tokenize(vocab: OpaquePointer!, text: String, addSpecial: Bool, parseSpecial: Bool) -> [llama_token]? {
        guard let vocab else { return nil }
        return text.withCString { cstr in
            let textLen = Int32(strlen(cstr))
            // First call to get token count
            let nTokens = llama_tokenize(vocab, cstr, textLen, nil, 0, addSpecial, parseSpecial)
            let count = abs(nTokens)
            guard count > 0 else { return [] }

            var tokens = [llama_token](repeating: 0, count: Int(count))
            let result = llama_tokenize(vocab, cstr, textLen, &tokens, count, addSpecial, parseSpecial)
            return result >= 0 ? Array(tokens.prefix(Int(result))) : nil
        }
    }

    /// Detokenize tokens back to text.
    private func detokenize(vocab: OpaquePointer!, tokens: [llama_token]) -> String {
        guard let vocab else { return "" }
        var result = ""
        // +1 for null terminator to avoid out-of-bounds write
        var buf = [CChar](repeating: 0, count: 257)

        for token in tokens {
            let n = llama_token_to_piece(vocab, token, &buf, Int32(buf.count - 1), 0, false)
            if n > 0 {
                buf[Int(n)] = 0
                result += String(cString: buf)
            } else if n < 0 {
                // Buffer too small — allocate larger buffer for this token
                let needed = -n
                var largeBuf = [CChar](repeating: 0, count: Int(needed) + 1)
                let n2 = llama_token_to_piece(vocab, token, &largeBuf, needed, 0, false)
                if n2 > 0 {
                    largeBuf[Int(n2)] = 0
                    result += String(cString: largeBuf)
                }
            }
        }

        return result
    }

    deinit {
        // freeResources() is called here directly because deinit means no other references exist.
        // LlamaBridge is always cleaned up explicitly via freeModelSync() before the last reference
        // is dropped (in AppDelegate.applicationShouldTerminate), so this is a safety net only.
        if ctx != nil {
            llama_free(ctx)
        }
        if model != nil {
            llama_model_free(model)
        }
    }
}
