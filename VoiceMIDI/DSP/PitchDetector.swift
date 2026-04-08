import Foundation

class PitchDetector {
    private var yin: UnsafeMutablePointer<YIN>

    init(bufferSize: Int32 = 2048, threshold: Float = 0.12) {
        guard let ptr = yin_create(bufferSize, threshold) else {
            fatalError("Failed to allocate YIN pitch detector")
        }
        yin = ptr
    }

    deinit {
        yin_destroy(yin)
    }

    /// Returns (frequency: Float, confidence: Float).
    /// frequency is 0 if no pitch detected.
    func detect(audioBuffer: UnsafePointer<Float>, sampleRate: Int32) -> (Float, Float) {
        let frequency = yin_detect(yin, audioBuffer, sampleRate)
        let confidence = yin.pointee.probability
        return (frequency, confidence)
    }
}
