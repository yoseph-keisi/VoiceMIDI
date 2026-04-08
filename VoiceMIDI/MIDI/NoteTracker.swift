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

    // Smoothed frequency — EMA applied here so NoteTracker owns pitch stability
    private var smoothedFrequency: Float = 0

    // Onset: require N consecutive stable frames before note-on
    private var onsetDebounceCount: Int = 0
    private let onsetDebounceRequired = 4   // ~12ms at 128-sample buffer
    private var pendingNote: UInt8 = 0

    // Release holdoff: require N consecutive below-threshold frames before note-off
    private var releaseHoldCount: Int = 0

    // Note-change debounce while sounding: require N frames at the new note before retriggering
    private var noteChangeCount: Int = 0
    private var pendingNewNote: UInt8 = 0

    // Last sent bend value — used for smoothing
    private var lastBendValue: UInt16 = 8192

    init(scaleQuantizer: ScaleQuantizer, midiEngine: MIDIEngine, midiConfig: MIDIConfig) {
        self.scaleQuantizer = scaleQuantizer
        self.midiEngine = midiEngine
        self.midiConfig = midiConfig
    }

    func process(frequency: Float, confidence: Float, rms: Float) {
        let channel = midiConfig.midiChannel

        // --- Frequency smoothing (EMA) ---
        // Only update smoothed frequency when we have a valid pitch reading.
        // When invalid, hold last value so it doesn't snap to zero.
        if frequency > 0 && confidence > 0.5 {
            let alpha = midiConfig.frequencySmoothingAlpha
            if smoothedFrequency == 0 {
                smoothedFrequency = frequency  // cold start
            } else {
                smoothedFrequency = alpha * frequency + (1 - alpha) * smoothedFrequency
            }
        }

        switch state {

        // ── SILENT ──────────────────────────────────────────────────────────────
        case .silent:
            // Reset release counter so it doesn't carry over
            releaseHoldCount = 0

            guard rms > midiConfig.onsetThreshold,
                  confidence > midiConfig.confidenceThreshold,
                  smoothedFrequency > 0 else {
                onsetDebounceCount = 0
                pendingNote = 0
                return
            }

            let (quantizedNote, _) = scaleQuantizer.quantize(frequency: smoothedFrequency)
            let note = UInt8(max(0, min(127, quantizedNote)))

            if note == pendingNote {
                onsetDebounceCount += 1
            } else {
                pendingNote = note
                onsetDebounceCount = 1
            }

            if onsetDebounceCount >= onsetDebounceRequired {
                // Fire note-on with center pitch bend (no pre-bend wobble on attack)
                lastBendValue = 8192
                midiEngine.sendPitchBend(value: 8192, channel: channel)
                let velocity = velocityFromRMS(rms)
                midiEngine.sendNoteOn(note: pendingNote, velocity: velocity, channel: channel)
                state = .sounding(currentNote: pendingNote)
                smoothedFrequency = frequency  // re-anchor on actual onset frequency
                onsetDebounceCount = 0
                noteChangeCount = 0
                pendingNewNote = 0
            }

        // ── SOUNDING ────────────────────────────────────────────────────────────
        case .sounding(let currentNote):
            let releaseConfThreshold = midiConfig.confidenceThreshold * 0.65

            // Release condition check (with holdoff)
            let shouldRelease = rms < midiConfig.releaseThreshold ||
                                (confidence < releaseConfThreshold && smoothedFrequency == 0)

            if shouldRelease {
                releaseHoldCount += 1
                if releaseHoldCount >= midiConfig.releaseHoldFrames {
                    midiEngine.sendNoteOff(note: currentNote, channel: channel)
                    midiEngine.sendPitchBend(value: 8192, channel: channel)
                    state = .silent
                    smoothedFrequency = 0
                    onsetDebounceCount = 0
                    noteChangeCount = 0
                    pendingNewNote = 0
                    lastBendValue = 8192
                }
                // While counting down, keep sending expression but don't update note
                return
            } else {
                // Condition cleared — reset release counter
                releaseHoldCount = 0
            }

            guard confidence > releaseConfThreshold, smoothedFrequency > 0 else { return }

            // --- Compute deviation from the CURRENT note (not re-quantizing every frame) ---
            // This prevents scale-boundary flipping from causing false retriggers.
            let exactNote = 69.0 + 12.0 * log2(Double(smoothedFrequency) / 440.0)
            let deviationSemitones = Float(exactNote) - Float(currentNote)

            // --- Pitch bend with dead zone ---
            let bend: UInt16
            let deadZone = midiConfig.pitchBendDeadZoneSemitones
            if abs(deviationSemitones) < deadZone {
                // Within dead zone — snap to center, no wobble
                bend = 8192
            } else {
                // Outside dead zone — apply bend, but shrink by the dead zone so it starts from 0
                let adjustedDeviation = deviationSemitones > 0
                    ? deviationSemitones - deadZone
                    : deviationSemitones + deadZone
                bend = pitchBendValue(semitoneOffset: adjustedDeviation)
            }

            // Smooth the bend value to avoid steppy transitions
            let smoothedBend = UInt16((Int(lastBendValue) * 3 + Int(bend)) / 4)
            if smoothedBend != lastBendValue {
                midiEngine.sendPitchBend(value: smoothedBend, channel: channel)
                lastBendValue = smoothedBend
            }

            // --- Note change detection ---
            // Only retrigger if deviation is large AND sustained for N frames
            let threshold = midiConfig.retriggerSemitoneThreshold

            if abs(deviationSemitones) >= threshold && !midiConfig.glideMode {
                // Determine target note (quantized to scale)
                let (quantizedNote, _) = scaleQuantizer.quantize(frequency: smoothedFrequency)
                let newNote = UInt8(max(0, min(127, quantizedNote)))

                if newNote == pendingNewNote && newNote != currentNote {
                    noteChangeCount += 1
                } else {
                    pendingNewNote = newNote
                    noteChangeCount = newNote != currentNote ? 1 : 0
                }

                if noteChangeCount >= midiConfig.retriggerDebounceFrames {
                    midiEngine.sendNoteOff(note: currentNote, channel: channel)
                    midiEngine.sendPitchBend(value: 8192, channel: channel)
                    let velocity = velocityFromRMS(rms)
                    midiEngine.sendNoteOn(note: newNote, velocity: velocity, channel: channel)
                    state = .sounding(currentNote: newNote)
                    lastBendValue = 8192
                    noteChangeCount = 0
                    pendingNewNote = 0
                }
            } else {
                // Back within range — reset change counter
                noteChangeCount = 0
                pendingNewNote = 0
            }

            // --- Expression CC 11 ---
            if midiConfig.sendExpression {
                let expr = UInt8(min(127, max(0, Int(rms * midiConfig.velocitySensitivity * 0.4))))
                midiEngine.sendCC(controller: 11, value: expr, channel: channel)
            }
        }
    }

    // MARK: - Helpers

    private func pitchBendValue(semitoneOffset: Float) -> UInt16 {
        let range = Float(midiConfig.pitchBendRangeSemitones)
        let clamped = max(-range, min(range, semitoneOffset))
        let normalized = clamped / range
        let value = 8192.0 + normalized * 8191.0
        return UInt16(max(0, min(16383, Int(value.rounded()))))
    }

    private func velocityFromRMS(_ rms: Float) -> UInt8 {
        let raw = rms * midiConfig.velocitySensitivity
        return UInt8(min(127, max(1, Int(raw))))
    }
}
