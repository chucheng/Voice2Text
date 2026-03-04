import Foundation
import CoreML

/// In-process BERT-based Chinese punctuation restoration using CoreML.
/// Replaces the external PunctuationServer.app entirely.
final class PunctuationRestorer {
    private var model: MLModel?
    private let tokenizer: WordPieceTokenizer?
    private let queue = DispatchQueue(label: "com.voice2text.punctuation", qos: .userInitiated)

    /// Label mapping from model output index to punctuation character.
    /// Must match the training labels of p208p2002/zh-wiki-punctuation-restore.
    /// Source: config.json id2label — 7 labels (0-6).
    private static let labels: [Int: String] = [
        // 0: O (no punctuation)
        1: "，",
        2: "、",
        3: "。",
        4: "？",
        5: "！",
        6: "；",
    ]

    private static let maxSeqLen = 512

    /// Model file name in Application Support.
    static let modelFileName = "zh-punctuation-bert.mlpackage"

    /// Full path to the downloaded model.
    static var modelPath: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("Voice2Text/\(modelFileName)")
    }

    /// Check if the model file exists on disk.
    static var isModelDownloaded: Bool {
        FileManager.default.fileExists(atPath: modelPath.path)
    }

    /// GitHub Releases URL for the model zip.
    static let downloadURL = URL(string: "https://github.com/chucheng/Voice2Text/releases/latest/download/zh-punctuation-bert.mlpackage.zip")!

    init() {
        tokenizer = WordPieceTokenizer()
    }

    /// Whether the model is currently loaded and ready for inference.
    var isLoaded: Bool { queue.sync { model != nil } }

    /// Load the CoreML model from disk. Returns true on success.
    /// Must be called from a background thread (compilation can be slow).
    @discardableResult
    func loadModel() -> Bool {
        guard tokenizer != nil else {
            print("[PunctuationRestorer] Failed: vocab.txt not found in bundle")
            return false
        }

        let path = Self.modelPath
        guard FileManager.default.fileExists(atPath: path.path) else {
            print("[PunctuationRestorer] Model not found at \(path.path)")
            return false
        }

        do {
            let config = MLModelConfiguration()
            config.computeUnits = .cpuAndGPU
            let compiledURL = try MLModel.compileModel(at: path)
            let loadedModel = try MLModel(contentsOf: compiledURL, configuration: config)
            queue.sync { model = loadedModel }
            print("[PunctuationRestorer] Model loaded successfully")
            return true
        } catch {
            print("[PunctuationRestorer] Failed to load model: \(error.localizedDescription)")
            queue.sync { model = nil }
            return false
        }
    }

    /// Unload the model to free memory.
    func unloadModel() {
        queue.sync { model = nil }
    }

    /// Restore punctuation in the given text. Calls completion on main queue.
    func restore(_ text: String, completion: @escaping (String?, String?) -> Void) {
        guard isLoaded, tokenizer != nil else {
            DispatchQueue.main.async { completion(nil, "Model not loaded") }
            return
        }

        queue.async { [weak self] in
            guard let self, let tokenizer = self.tokenizer, self.model != nil else {
                DispatchQueue.main.async { completion(nil, "Model not loaded") }
                return
            }

            let tokenCount = tokenizer.countTokens(text)
            let maxContentTokens = Self.maxSeqLen - 2  // reserve [CLS] and [SEP]

            let result: String
            if tokenCount <= maxContentTokens {
                result = self.restoreChunk(text)
            } else {
                result = self.restoreWithChunking(text, maxContentTokens: maxContentTokens)
            }

            DispatchQueue.main.async { completion(result, nil) }
        }
    }

    // MARK: - Single Chunk Inference

    /// Process a single chunk that fits within the model's max sequence length.
    private func restoreChunk(_ text: String) -> String {
        guard let tokenizer, model != nil else { return text }

        // NFC normalize to match tokenizer's internal normalization (offsets are character-based)
        let normalized = text.precomposedStringWithCanonicalMapping
        let encoding = tokenizer.encode(normalized, maxLength: Self.maxSeqLen)

        guard let prediction = predict(inputIds: encoding.inputIds, attentionMask: encoding.attentionMask) else {
            return text
        }

        return applyPunctuation(text: normalized, offsets: encoding.offsets, predictions: prediction)
    }

    /// Run CoreML prediction. Returns array of predicted label indices per token (excluding [CLS]/[SEP]).
    private func predict(inputIds: [Int32], attentionMask: [Int32]) -> [Int]? {
        guard let model else { return nil }

        do {
            let inputIdsArray = try MLMultiArray(shape: [1, NSNumber(value: Self.maxSeqLen)], dataType: .int32)
            let attentionMaskArray = try MLMultiArray(shape: [1, NSNumber(value: Self.maxSeqLen)], dataType: .int32)

            for i in 0..<Self.maxSeqLen {
                inputIdsArray[i] = NSNumber(value: inputIds[i])
                attentionMaskArray[i] = NSNumber(value: attentionMask[i])
            }

            let provider = try MLDictionaryFeatureProvider(dictionary: [
                "input_ids": MLFeatureValue(multiArray: inputIdsArray),
                "attention_mask": MLFeatureValue(multiArray: attentionMaskArray),
            ])

            let output = try model.prediction(from: provider)

            guard let logits = output.featureValue(for: "logits")?.multiArrayValue else {
                return nil
            }

            // logits shape: [1, 512, num_labels]
            let numLabels = logits.shape[2].intValue
            let contentTokenCount = attentionMask.reduce(0) { $0 + Int($1) } - 2  // minus [CLS] and [SEP]

            var predictions: [Int] = []
            for i in 0..<contentTokenCount {
                let tokenIdx = i + 1  // skip [CLS] at position 0
                var maxVal: Float = -Float.infinity
                var maxIdx = 0
                for j in 0..<numLabels {
                    let idx = tokenIdx * numLabels + j
                    let val = logits[idx].floatValue
                    if val > maxVal {
                        maxVal = val
                        maxIdx = j
                    }
                }
                predictions.append(maxIdx)
            }

            return predictions
        } catch {
            print("[PunctuationRestorer] Prediction error: \(error.localizedDescription)")
            return nil
        }
    }

    /// Apply predicted punctuation labels to the original text using offset mapping.
    private func applyPunctuation(text: String, offsets: [WordPieceTokenizer.TokenOffset], predictions: [Int]) -> String {
        guard !offsets.isEmpty, offsets.count == predictions.count else { return text }

        // Build a map: character index → punctuation to insert after it
        // For subword tokens (##), only the last subword in a word group gets punctuation.
        var punctuationAfter: [Int: String] = [:]

        for i in 0..<offsets.count {
            let offset = offsets[i]
            let label = predictions[i]

            // Only apply punctuation from the last subword token of each word
            let isLastSubword = (i == offsets.count - 1) || (offsets[i + 1].start != offset.start)

            if isLastSubword, let punct = Self.labels[label] {
                // Insert punctuation after the last character of this word
                punctuationAfter[offset.end - 1] = punct
            }
        }

        // Reconstruct text with punctuation inserted
        let chars = Array(text)
        var result = ""
        for (i, char) in chars.enumerated() {
            result.append(char)
            if let punct = punctuationAfter[i] {
                result.append(punct)
            }
        }

        return result
    }

    // MARK: - Chunking for Long Text

    /// Process text that exceeds the model's max token length by splitting into chunks.
    private func restoreWithChunking(_ text: String, maxContentTokens: Int) -> String {
        guard let tokenizer else { return text }

        var chunks: [String] = []
        var remaining = text

        while !remaining.isEmpty {
            let maxChars = estimateMaxChars(remaining, maxTokens: maxContentTokens)
            let splitIdx = findSplitPoint(remaining, maxChars: maxChars)

            let chunkEndIndex = remaining.index(remaining.startIndex, offsetBy: splitIdx, limitedBy: remaining.endIndex) ?? remaining.endIndex
            let chunk = String(remaining[remaining.startIndex..<chunkEndIndex])
            chunks.append(chunk)

            remaining = String(remaining[chunkEndIndex...])
        }

        // Process each chunk
        var results: [String] = []
        for chunk in chunks {
            // Verify chunk fits
            let count = tokenizer.countTokens(chunk)
            if count <= maxContentTokens {
                results.append(restoreChunk(chunk))
            } else {
                // Shouldn't happen, but fallback to raw text
                results.append(chunk)
            }
        }

        return results.joined()
    }

    /// Binary search to estimate max characters that fit within maxTokens.
    private func estimateMaxChars(_ text: String, maxTokens: Int) -> Int {
        guard let tokenizer else { return text.count }

        var lo = 0
        var hi = text.count
        var best = min(maxTokens, text.count)  // conservative start

        while lo <= hi {
            let mid = (lo + hi) / 2
            let prefix = String(text.prefix(mid))
            let count = tokenizer.countTokens(prefix)

            if count <= maxTokens {
                best = mid
                lo = mid + 1
            } else {
                hi = mid - 1
            }
        }

        return best
    }

    /// Find a good split point within maxChars: prefer newline > period/question > space > hard split.
    private func findSplitPoint(_ text: String, maxChars: Int) -> Int {
        let limit = min(maxChars, text.count)
        if limit >= text.count { return text.count }

        let chars = Array(text.prefix(limit))

        // Search backwards for a good split point
        for i in stride(from: chars.count - 1, through: max(0, chars.count - 100), by: -1) {
            if chars[i] == "\n" { return i + 1 }
        }

        for i in stride(from: chars.count - 1, through: max(0, chars.count - 100), by: -1) {
            let c = chars[i]
            if c == "。" || c == "？" || c == "！" || c == "." || c == "?" || c == "!" {
                return i + 1
            }
        }

        for i in stride(from: chars.count - 1, through: max(0, chars.count - 100), by: -1) {
            if chars[i] == " " || chars[i] == "，" || chars[i] == "," {
                return i + 1
            }
        }

        // Hard split at maxChars
        return limit
    }
}
