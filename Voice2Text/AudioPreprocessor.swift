import Foundation
import Accelerate

/// Audio preprocessing: high-pass filter (80Hz) to remove low-frequency noise,
/// then RMS normalization to ~-20 dBFS target level.
/// Extracted from AppState for testability.
struct AudioPreprocessor {
    /// Single-pole high-pass filter state (persists across calls for streaming)
    var filterState: Float = 0.0

    /// High-pass filter cutoff coefficient.
    /// alpha = 1 / (1 + 2π * fc / fs) ≈ 0.969 for 80Hz at 16kHz sample rate.
    static let alpha: Float = 0.969

    /// RMS normalization target (~-20 dBFS)
    static let targetRMS: Float = 0.1

    /// Minimum RMS to apply normalization (below this is near-silence)
    static let silenceThreshold: Float = 0.0001

    /// Preprocess audio: high-pass filter then RMS normalize.
    /// - Parameter samples: PCM Float32 audio samples (16kHz)
    /// - Returns: Filtered and normalized samples, clamped to [-1, 1]
    mutating func process(_ samples: [Float]) -> [Float] {
        guard !samples.isEmpty else { return samples }

        // 1. High-pass filter (~80Hz cutoff at 16kHz sample rate)
        // Single-pole IIR: y[n] = alpha * (y[n-1] + x[n] - x[n-1])
        let alpha = Self.alpha
        var filtered = [Float](repeating: 0, count: samples.count)
        var prev_x: Float = samples[0]
        var prev_y: Float = filterState
        for i in 0..<samples.count {
            prev_y = alpha * (prev_y + samples[i] - prev_x)
            prev_x = samples[i]
            filtered[i] = prev_y
        }
        filterState = prev_y

        // 2. RMS normalization to target ~-20 dBFS
        var sumSq: Float = 0
        vDSP_measqv(filtered, 1, &sumSq, vDSP_Length(filtered.count))
        let rms = sqrt(sumSq)
        guard rms > Self.silenceThreshold else { return filtered }

        let scale = Self.targetRMS / rms

        var result = [Float](repeating: 0, count: filtered.count)
        var s = scale
        vDSP_vsmul(filtered, 1, &s, &result, 1, vDSP_Length(filtered.count))
        // Clamp to [-1, 1]
        var lo: Float = -1.0
        var hi: Float = 1.0
        vDSP_vclip(result, 1, &lo, &hi, &result, 1, vDSP_Length(result.count))
        return result
    }
}
