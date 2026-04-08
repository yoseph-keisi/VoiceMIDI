import Foundation
import Combine

class MIDIConfig: ObservableObject {
    @Published var pitchBendRangeSemitones: Int = 2

    @Published var velocitySensitivity: Float = 800.0

    // ── Onset / Release ──────────────────────────────────────────────────────
    /// RMS above this triggers onset consideration
    @Published var onsetThreshold: Float = 0.01

    /// RMS below this contributes to release (primary release is confidence-based)
    @Published var releaseThreshold: Float = 0.006

    /// YIN confidence required to consider a pitch valid
    @Published var confidenceThreshold: Float = 0.80

    /// Consecutive frames both onset conditions must hold before note-on (~9ms)
    @Published var onsetDebounceFrames: Int = 3

    /// Consecutive frames a release condition must hold before note-off (~18ms).
    /// Short enough to feel responsive, long enough to survive a breath.
    @Published var releaseHoldFrames: Int = 6

    // ── Note Change ──────────────────────────────────────────────────────────
    /// Semitones of sustained deviation from current note before retrigger is considered
    @Published var retriggerSemitoneThreshold: Float = 1.5

    /// Consecutive frames at new pitch before retrigger fires (~9ms)
    @Published var retriggerDebounceFrames: Int = 3

    // ── Pitch Bend ───────────────────────────────────────────────────────────
    /// Dead zone around note center in semitones — no bend sent within this range.
    /// Prevents held notes from wobbling. 0.12 ≈ 12 cents.
    @Published var pitchBendDeadZoneSemitones: Float = 0.12

    // ── Smoothing ────────────────────────────────────────────────────────────
    /// EMA alpha for frequency smoothing (0=frozen, 1=raw).
    /// 0.45 gives ~6ms lag — kills jitter without perceptible delay.
    @Published var frequencySmoothingAlpha: Float = 0.45

    // ── Modes ────────────────────────────────────────────────────────────────
    @Published var sendExpression: Bool = true
    @Published var glideMode: Bool = false
    @Published var midiChannel: UInt8 = 0
}
