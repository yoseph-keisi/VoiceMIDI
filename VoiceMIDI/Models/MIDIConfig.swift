import Foundation
import Combine

class MIDIConfig: ObservableObject {
    @Published var pitchBendRangeSemitones: Int = 2     // ±2 default, options: 1, 2, 7, 12, 24
    @Published var velocitySensitivity: Float = 800.0   // Multiplier for RMS → velocity
    @Published var onsetThreshold: Float = 0.01
    @Published var releaseThreshold: Float = 0.005
    @Published var confidenceThreshold: Float = 0.85
    @Published var retriggerSemitoneThreshold: Float = 0.8
    @Published var sendExpression: Bool = true           // Map amplitude to CC 11
    @Published var glideMode: Bool = false               // If true, minimize retriggering — ride pitch bend instead
    @Published var midiChannel: UInt8 = 0               // 0–15 (0-indexed internally, display as 1-indexed)
}
