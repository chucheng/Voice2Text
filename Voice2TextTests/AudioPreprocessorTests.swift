import XCTest
import Accelerate
@testable import Voice2Text

final class AudioPreprocessorTests: XCTestCase {

    // MARK: - Empty input

    func testEmptyInput() {
        var proc = AudioPreprocessor()
        let result = proc.process([])
        XCTAssertTrue(result.isEmpty)
    }

    // MARK: - Silence (near-zero input)

    func testSilenceNotAmplified() {
        var proc = AudioPreprocessor()
        // Very quiet signal — below silence threshold
        let samples = [Float](repeating: 0.00001, count: 1600)
        let result = proc.process(samples)

        // Should not amplify noise — output should remain very small
        let maxAbs = result.map { abs($0) }.max() ?? 0
        XCTAssertLessThan(maxAbs, 0.01, "Near-silence should not be amplified")
    }

    func testAllZeros() {
        var proc = AudioPreprocessor()
        let samples = [Float](repeating: 0, count: 1600)
        let result = proc.process(samples)

        // All zeros → high-pass filter produces zeros, RMS is 0 → skip normalization
        for val in result {
            XCTAssertEqual(val, 0, accuracy: 1e-6)
        }
    }

    // MARK: - RMS Normalization

    func testRMSNormalization() {
        var proc = AudioPreprocessor()
        // Generate a sine wave at known amplitude
        let sampleRate: Float = 16000
        let freq: Float = 440 // Hz — well above 80Hz cutoff
        let amplitude: Float = 0.01 // quiet signal
        let count = 16000 // 1 second
        var samples = [Float](repeating: 0, count: count)
        for i in 0..<count {
            samples[i] = amplitude * sin(2 * .pi * freq * Float(i) / sampleRate)
        }

        let result = proc.process(samples)

        // Compute output RMS
        var sumSq: Float = 0
        vDSP_measqv(result, 1, &sumSq, vDSP_Length(result.count))
        let outputRMS = sqrt(sumSq)

        // Should be close to target RMS (0.1)
        // Allow some tolerance due to high-pass filter transient
        XCTAssertEqual(outputRMS, AudioPreprocessor.targetRMS, accuracy: 0.03,
                       "Output RMS should be near target \(AudioPreprocessor.targetRMS)")
    }

    func testLoudSignalNormalized() {
        var proc = AudioPreprocessor()
        // Loud signal
        let count = 16000
        var samples = [Float](repeating: 0, count: count)
        for i in 0..<count {
            samples[i] = 0.8 * sin(2 * .pi * 440 * Float(i) / 16000)
        }

        let result = proc.process(samples)

        var sumSq: Float = 0
        vDSP_measqv(result, 1, &sumSq, vDSP_Length(result.count))
        let outputRMS = sqrt(sumSq)

        // Should be scaled down toward target
        XCTAssertEqual(outputRMS, AudioPreprocessor.targetRMS, accuracy: 0.03)
    }

    // MARK: - Clipping

    func testOutputClampedToMinusOnePlusOne() {
        var proc = AudioPreprocessor()
        // Extremely quiet high-frequency signal that will be amplified a lot
        // Actually, let's use a signal that after normalization would exceed 1.0
        // A signal with a spike
        var samples = [Float](repeating: 0.001, count: 16000)
        samples[8000] = 0.5 // spike — after normalization the spike could clip

        let result = proc.process(samples)

        for val in result {
            XCTAssertGreaterThanOrEqual(val, -1.0, "Output should be >= -1.0")
            XCTAssertLessThanOrEqual(val, 1.0, "Output should be <= 1.0")
        }
    }

    // MARK: - High-Pass Filter

    func testHighPassRemovesDC() {
        var proc = AudioPreprocessor()
        // DC offset (constant value) — should be removed by high-pass
        let samples = [Float](repeating: 0.5, count: 16000)
        let result = proc.process(samples)

        // After high-pass, the constant should decay toward zero
        // Check the last samples are near zero (filter has settled)
        let lastChunk = Array(result.suffix(1000))
        let avgLast = lastChunk.reduce(0, +) / Float(lastChunk.count)
        XCTAssertEqual(avgLast, 0, accuracy: 0.01,
                       "High-pass filter should remove DC offset")
    }

    func testHighPassPassesHighFrequency() {
        var proc = AudioPreprocessor()
        // 1kHz tone — well above 80Hz cutoff, should pass through
        let count = 16000
        var samples = [Float](repeating: 0, count: count)
        let amplitude: Float = 0.1
        for i in 0..<count {
            samples[i] = amplitude * sin(2 * .pi * 1000 * Float(i) / 16000)
        }

        let result = proc.process(samples)

        // Output should have significant energy (not filtered out)
        var sumSq: Float = 0
        vDSP_measqv(result, 1, &sumSq, vDSP_Length(result.count))
        let outputRMS = sqrt(sumSq)
        XCTAssertGreaterThan(outputRMS, 0.05, "1kHz should pass through high-pass filter")
    }

    // MARK: - Filter State Persistence

    func testFilterStatePersistsAcrossCalls() {
        var proc = AudioPreprocessor()
        XCTAssertEqual(proc.filterState, 0.0)

        // Process a sine wave — filter state tracks the IIR output
        var samples = [Float](repeating: 0, count: 1600)
        for i in 0..<1600 {
            samples[i] = 0.5 * sin(2 * .pi * 440 * Float(i) / 16000)
        }
        _ = proc.process(samples)

        // Filter state should have been updated (non-zero after processing a signal)
        XCTAssertNotEqual(proc.filterState, 0.0, "Filter state should persist across process() calls")
    }

    func testResetFilterState() {
        var proc = AudioPreprocessor()
        let samples = [Float](repeating: 0.1, count: 1600)
        _ = proc.process(samples)

        // Reset
        proc.filterState = 0.0
        XCTAssertEqual(proc.filterState, 0.0)
    }

    // MARK: - Constants

    func testConstants() {
        XCTAssertEqual(AudioPreprocessor.alpha, 0.969, accuracy: 0.001)
        XCTAssertEqual(AudioPreprocessor.targetRMS, 0.1, accuracy: 0.001)
        XCTAssertEqual(AudioPreprocessor.silenceThreshold, 0.0001, accuracy: 0.00001)
    }

    // MARK: - Single sample

    func testSingleSample() {
        var proc = AudioPreprocessor()
        let result = proc.process([0.5])
        XCTAssertEqual(result.count, 1)
        // Should not crash with single sample
    }
}
