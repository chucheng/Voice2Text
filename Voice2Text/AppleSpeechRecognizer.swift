import Foundation
import Speech

final class AppleSpeechRecognizer {
    private var recognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?

    init() {
        // Use zh-Hant for Traditional Chinese (also handles English mixed in)
        recognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh-Hant"))
    }

    /// Request speech recognition permission.
    func requestPermission(completion: @escaping (Bool) -> Void) {
        SFSpeechRecognizer.requestAuthorization { status in
            DispatchQueue.main.async {
                completion(status == .authorized)
            }
        }
    }

    /// Start a recognition request. Returns the audio buffer request to feed audio into.
    func startRecognition(onResult: @escaping (String, Bool) -> Void,
                          onError: @escaping (String) -> Void) -> SFSpeechAudioBufferRecognitionRequest? {
        guard let recognizer, recognizer.isAvailable else {
            onError("Speech recognizer not available")
            return nil
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.addsPunctuation = true

        recognitionRequest = request
        recognitionTask = recognizer.recognitionTask(with: request) { result, error in
            if let result {
                let text = result.bestTranscription.formattedString
                let isFinal = result.isFinal
                DispatchQueue.main.async {
                    onResult(text, isFinal)
                }
            }
            if let error {
                DispatchQueue.main.async {
                    onError(error.localizedDescription)
                }
            }
        }

        return request
    }

    func stopRecognition() {
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil
    }
}
