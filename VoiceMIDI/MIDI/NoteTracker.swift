import Foundation

class NoteTracker {
    enum State {
        case silent
        case sounding(currentNote: UInt8)
    }

    var state: State = .silent
    var scaleQuantizer: ScaleQuantizer
    var midiEngine: MIDIEngine
    var midiConfig: MIDIConfig

    // Onset debounce: require 2 stable pitch callbacks before firing note-on
    private var onsetDebounceCount: Int = 0
    private let onsetDebounceRequired = 2
    private var pendingNote: UInt8 = 0
    private var pendingBend: UInt16 = 8192

    init(scaleQuantizer: ScaleQuantizer, midiEngine: MIDIEngine, midiConfig: MIDIConfig) {
        self.scaleQuantizer = scaleQuantizer
        self.midiEngine = midiEngine
        self.midiConfig = midiConfig
    }

    func process(frequency: Float, confidence: Float, rms: Float) {
        let channel = midiConfig.midiChannel

        switch state {
        case .silent:
            if rms > midiConfig.onsetThreshold && confidence > midiConfig.confidenceThreshold && frequency > 0 {
                let (quantizedNote, bendOffsetSemitones) = scaleQuantizer.quantize(frequency: frequency)
                let clampedNote = UInt8(max(0, min(127, quantizedNote)))
                let bendValue = pitchBendValue(semitoneOffset: bendOffsetSemitones)

                // Onset debounce: accumulate stable callbacks
                if clampedNote == pendingNote {
                    onsetDebounceCount += 1
                } else {
                    pendingNote = clampedNote
                    pendingBend = bendValue
                    onsetDebounceCount = 1
                }

                if onsetDebounceCount >= onsetDebounceRequired {
                    let velocity = velocityFromRMS(rms)
                    midiEngine.sendPitchBend(value: pendingBend, channel: channel)
                    midiEngine.sendNoteOn(note: pendingNote, velocity: velocity, channel: channel)
                    state = .sounding(currentNote: pendingNote)
                    onsetDebounceCount = 0
                }
            } else {
                onsetDebounceCount = 0
            }

        case .sounding(let currentNote):
            let releaseConfidenceThreshold = midiConfig.confidenceThreshold * 0.7

            if rms < midiConfig.releaseThreshold || (frequency <= 0 && confidence < releaseConfidenceThreshold) {
                midiEngine.sendNoteOff(note: currentNote, channel: channel)
                state = .silent
                onsetDebounceCount = 0
                return
            }

            guard frequency > 0, confidence > releaseConfidenceThreshold else { return }

            let (quantizedNote, bendOffsetSemitones) = scaleQuantizer.quantize(frequency: frequency)
            let newNote = UInt8(max(0, min(127, quantizedNote)))
            let bendValue = pitchBendValue(semitoneOffset: bendOffsetSemitones)

            let semitoneDistance = abs(Int(newNote) - Int(currentNote))

            if midiConfig.glideMode {
                // In glide mode, ride pitch bend, minimize retriggering
                midiEngine.sendPitchBend(value: bendValue, channel: channel)
            } else if newNote != currentNote && Float(semitoneDistance) > midiConfig.retriggerSemitoneThreshold {
                // Retrigger on significant pitch jump
                midiEngine.sendNoteOff(note: currentNote, channel: channel)
                midiEngine.sendPitchBend(value: bendValue, channel: channel)
                let velocity = velocityFromRMS(rms)
                midiEngine.sendNoteOn(note: newNote, velocity: velocity, channel: channel)
                state = .sounding(currentNote: newNote)
            } else {
                // Same note or small movement — update pitch bend for expression
                midiEngine.sendPitchBend(value: bendValue, channel: channel)
            }

            // Optionally send expression CC 11
            if midiConfig.sendExpression {
                let expressionValue = UInt8(min(127, max(0, Int(rms * midiConfig.velocitySensitivity * 0.5))))
                midiEngine.sendCC(controller: 11, value: expressionValue, channel: channel)
            }
        }
    }

    /// Maps a semitone offset to a 14-bit MIDI pitch bend value.
    /// Clamps to ±pitchBendRangeSemitones.
    private func pitchBendValue(semitoneOffset: Float) -> UInt16 {
        let range = Float(midiConfig.pitchBendRangeSemitones)
        let clamped = max(-range, min(range, semitoneOffset))
        let normalized = clamped / range  // -1.0 to +1.0
        let bendValue = 8192.0 + normalized * 8191.0
        return UInt16(max(0, min(16383, Int(bendValue.rounded()))))
    }

    private func velocityFromRMS(_ rms: Float) -> UInt8 {
        let raw = rms * midiConfig.velocitySensitivity
        return UInt8(min(127, max(1, Int(raw))))
    }
}
