import Foundation

/// WordPiece tokenizer for BERT punctuation restoration.
/// Loads vocab.txt from the app bundle and tokenizes text into subword tokens.
final class WordPieceTokenizer {
    private var vocab: [String: Int32] = [:]
    private var idToToken: [Int32: String] = [:]
    private let unkTokenId: Int32
    private let clsTokenId: Int32
    private let sepTokenId: Int32
    private let padTokenId: Int32

    /// Each token's mapping back to the original text: (startIndex, endIndex) in the input string.
    struct TokenOffset {
        let start: Int
        let end: Int
    }

    struct EncodingResult {
        let inputIds: [Int32]
        let attentionMask: [Int32]
        /// One offset per token (excluding [CLS] and [SEP]).
        /// Maps each content token to its character range in the original text.
        let offsets: [TokenOffset]
    }

    init?() {
        guard let url = Bundle.main.url(forResource: "vocab", withExtension: "txt"),
              let content = try? String(contentsOf: url, encoding: .utf8) else {
            return nil
        }
        let lines = content.components(separatedBy: "\n")
        for (index, line) in lines.enumerated() {
            guard !line.isEmpty else { continue }
            vocab[line] = Int32(index)
            idToToken[Int32(index)] = line
        }

        guard let unk = vocab["[UNK]"],
              let cls = vocab["[CLS]"],
              let sep = vocab["[SEP]"],
              let pad = vocab["[PAD]"] else {
            return nil
        }
        unkTokenId = unk
        clsTokenId = cls
        sepTokenId = sep
        padTokenId = pad
    }

    var vocabSize: Int { vocab.count }

    /// Count the number of tokens (excluding [CLS]/[SEP]) for the given text.
    func countTokens(_ text: String) -> Int {
        let words = tokenizeToWords(text)
        var count = 0
        for word in words {
            count += wordPieceTokenize(word.token).count
        }
        return count
    }

    /// Encode text into input_ids, attention_mask, and offset mapping.
    /// The result is padded to `maxLength`.
    func encode(_ text: String, maxLength: Int = 512) -> EncodingResult {
        let words = tokenizeToWords(text)

        var allTokenIds: [Int32] = []
        var allOffsets: [TokenOffset] = []

        for word in words {
            let subwords = wordPieceTokenize(word.token)
            for subId in subwords {
                allTokenIds.append(subId)
                allOffsets.append(TokenOffset(start: word.start, end: word.end))
            }
        }

        // Truncate to fit [CLS] ... [SEP] within maxLength
        let maxContentTokens = maxLength - 2
        if allTokenIds.count > maxContentTokens {
            allTokenIds = Array(allTokenIds.prefix(maxContentTokens))
            allOffsets = Array(allOffsets.prefix(maxContentTokens))
        }

        // Build final sequences
        var inputIds: [Int32] = [clsTokenId]
        inputIds.append(contentsOf: allTokenIds)
        inputIds.append(sepTokenId)

        var attentionMask = [Int32](repeating: 1, count: inputIds.count)

        // Pad to maxLength
        let padCount = maxLength - inputIds.count
        if padCount > 0 {
            inputIds.append(contentsOf: [Int32](repeating: padTokenId, count: padCount))
            attentionMask.append(contentsOf: [Int32](repeating: 0, count: padCount))
        }

        return EncodingResult(
            inputIds: inputIds,
            attentionMask: attentionMask,
            offsets: allOffsets
        )
    }

    /// Decode a token ID back to its string representation.
    func decode(_ id: Int32) -> String {
        idToToken[id] ?? "[UNK]"
    }

    // MARK: - Internal

    private struct WordToken {
        let token: String
        let start: Int
        let end: Int
    }

    /// Split text into words with character offsets.
    /// For Chinese/CJK characters, each character is its own word.
    /// For Latin text, split on whitespace.
    private func tokenizeToWords(_ text: String) -> [WordToken] {
        // Unicode NFC normalization
        let normalized = text.precomposedStringWithCanonicalMapping

        var words: [WordToken] = []
        var currentWord = ""
        var wordStart = 0
        var charIndex = 0

        for char in normalized {
            if isCJKCharacter(char) {
                // Flush any pending Latin word
                if !currentWord.isEmpty {
                    words.append(WordToken(token: currentWord.lowercased(), start: wordStart, end: charIndex))
                    currentWord = ""
                }
                // Each CJK character is its own token
                words.append(WordToken(token: String(char), start: charIndex, end: charIndex + 1))
                charIndex += 1
            } else if char.isWhitespace {
                if !currentWord.isEmpty {
                    words.append(WordToken(token: currentWord.lowercased(), start: wordStart, end: charIndex))
                    currentWord = ""
                }
                charIndex += 1
            } else {
                if currentWord.isEmpty {
                    wordStart = charIndex
                }
                currentWord.append(char)
                charIndex += 1
            }
        }

        if !currentWord.isEmpty {
            words.append(WordToken(token: currentWord.lowercased(), start: wordStart, end: charIndex))
        }

        return words
    }

    /// WordPiece tokenization of a single word.
    private func wordPieceTokenize(_ word: String) -> [Int32] {
        if word.isEmpty { return [] }

        // Check if whole word is in vocab
        if let id = vocab[word] {
            return [id]
        }

        var tokens: [Int32] = []
        var start = word.startIndex
        let end = word.endIndex

        while start < end {
            var found = false
            var subEnd = end

            while subEnd > start {
                var substr = String(word[start..<subEnd])
                if start > word.startIndex {
                    substr = "##" + substr
                }

                if let id = vocab[substr] {
                    tokens.append(id)
                    start = subEnd
                    found = true
                    break
                }

                subEnd = word.index(before: subEnd)
            }

            if !found {
                tokens.append(unkTokenId)
                start = word.index(after: start)
            }
        }

        return tokens
    }

    private func isCJKCharacter(_ char: Character) -> Bool {
        guard let scalar = char.unicodeScalars.first else { return false }
        let v = scalar.value
        return (0x4E00...0x9FFF).contains(v) ||    // CJK Unified Ideographs
               (0x3400...0x4DBF).contains(v) ||    // CJK Extension A
               (0xF900...0xFAFF).contains(v) ||    // CJK Compatibility Ideographs
               (0x20000...0x2A6DF).contains(v) ||  // CJK Extension B
               (0x2A700...0x2B73F).contains(v) ||  // CJK Extension C
               (0x2B740...0x2B81F).contains(v) ||  // CJK Extension D
               (0x2B820...0x2CEAF).contains(v) ||  // CJK Extension E
               (0x2CEB0...0x2EBEF).contains(v)     // CJK Extension F
    }
}
