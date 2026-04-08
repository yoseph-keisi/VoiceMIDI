import Foundation
import Combine

class MIDIConfig: ObservableObject {
    @Published var pitchBendRangeSemitones: Int = 2       // ±2 default, options: 1, 2, 7, 12, 24
    @Published var velocitySensitivity: Float = 800.0     // Multiplier for RMS → velocity
    @Published var onsetThreshold: Float = 0.01
    @Published var releaseThreshold: Float = 0.008
    @Published var confidenceThreshold: Float = 0.80

    /// Semitone distance from the current note before a retrigger is considered.
    /// Must also be stable for retriggerDebounceFrames before firing.
    @Published var retriggerSemitoneThreshold: Float = 1.5

    /// Frames the release condition must hold before note-off fires (~45ms at 128-sample buffer).
    @Published var releaseHoldFrames: Int = 15

    /// Frames a new note must be stable (≥ retriggerSemitoneThreshold away) before retrigger fires.
    @Published var retriggerDebounceFrames: Int = 5

    /// Dead zone in semitones around the current note center — no pitch bend sent within this range.
    /// Keeps held notes from wobbling. 0.15 ≈ 15 cents.
    @Published var pitchBendDeadZoneSemitones: Float = 0.15

    /// EMA alpha for frequency smoothing in NoteTracker (0=frozen, 1=raw). Lower = smoother but slower.
    @Published var frequencySmoothingAlpha: Float = 0.25

    @Published var sendExpression: Bool = true            // Map amplitude to CC 11
    @Published var glideMode: Bool = false                // Minimize retriggering, ride pitch bend
    @Published var midiChannel: UInt8 = 0                // 0–15 (display as 1-indexed)
}
