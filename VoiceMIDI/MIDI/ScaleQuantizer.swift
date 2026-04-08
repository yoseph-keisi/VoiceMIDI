import Foundation
import Combine

class ScaleQuantizer: ObservableObject {
    @Published var enabledNotes: Set<Int> = Set(0...11)  // Chromatic by default (0=C, 1=C#, ..., 11=B)
    @Published var rootNote: Int = 0  // 0=C

    /// Snaps a MIDI note number to the nearest enabled scale degree.
    /// Returns the quantized MIDI note number.
    func quantize(midiNote: Int) -> Int {
        let pitchClass = ((midiNote % 12) + 12) % 12
        let relativePitchClass = ((pitchClass - rootNote) + 12) % 12

        if enabledNotes.contains(relativePitchClass) {
            return midiNote
        }

        // Search outward for nearest enabled note
        for delta in 1...12 {
            let upClass = (relativePitchClass + delta) % 12
            let downClass = ((relativePitchClass - delta) + 12) % 12

            if enabledNotes.contains(upClass) {
                return midiNote + delta
            }
            if enabledNotes.contains(downClass) {
                return midiNote - delta
            }
        }

        // Fallback — should never reach here if enabledNotes is non-empty
        return midiNote
    }

    /// Converts frequency to nearest quantized MIDI note.
    /// Returns (quantizedMIDINote, pitchBendOffset in semitones)
    func quantize(frequency: Float) -> (Int, Float) {
        guard frequency > 0 else { return (60, 0) }

        // Convert frequency to exact MIDI note number
        let exactNote = 69.0 + 12.0 * log2(Double(frequency) / 440.0)
        let rawMidiNote = Int(exactNote.rounded())

        let quantizedNote = quantize(midiNote: rawMidiNote)

        // Pitch bend offset: how many semitones the raw pitch is above/below the quantized note center
        let bendOffsetSemitones = Float(exactNote) - Float(quantizedNote)

        return (quantizedNote, bendOffsetSemitones)
    }

    func applyPreset(_ preset: Scale.Preset) {
        if preset == .custom { return }
        let intervals = preset.intervals
        // Shift intervals by rootNote to get the actual enabled pitch classes
        enabledNotes = Set(intervals.map { ($0 + rootNote) % 12 })
    }
}
