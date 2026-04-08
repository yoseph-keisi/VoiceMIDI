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

    // EMA-smoothed frequency — owned here so it resets correctly on state transitions
    private var smoothedFrequency: Float = 0

    // Onset debounce: N stable frames before note-on
    private var onsetCount: Int = 0
    private var onsetNote: UInt8 = 0

    // Release holdoff: N consecutive release-condition frames before note-off
    // Short — just enough to ride over a single dip (~6ms at 128-sample buffer)
    private var releaseCount: Int = 0

    // Note-change debounce while sounding
    private var noteChangeCount: Int = 0
    private var noteChangePending: UInt8 = 0

    // Last sent pitch bend (for smoothing)
    private var lastBend: UInt16 = 8192

    init(scaleQuantizer: ScaleQuantizer, midiEngine: MIDIEngine, midiConfig: MIDIConfig) {
        self.scaleQuantizer = scaleQuantizer
        self.midiEngine = midiEngine
        self.midiConfig = midiConfig
    }

    func process(frequency: Float, confidence: Float, rms: Float) {
        let channel = midiConfig.midiChannel
        let alpha = midiConfig.frequencySmoothingAlpha

        // ── Step 1: Octave-correct RAW frequency BEFORE EMA ─────────────────────
        // YIN on a voiced signal latches onto harmonic periods (÷2, ÷3 of true freq).
        // Correcting after EMA is too late — EMA already blends the wrong value down
        // to an intermediate frequency where ×mult no longer lands near the reference.
        // Reference: use smoothedFrequency (continuity) when available, else the
        // current note's Hz when sounding.
        var inputFrequency = frequency
        if frequency > 0 && confidence > 0.5 {
            let refFreq: Float
            if smoothedFrequency > 0 {
                refFreq = smoothedFrequency
            } else if case .sounding(let note) = state {
                refFreq = Float(440.0 * pow(2.0, Double(note - 69) / 12.0))
            } else {
                refFreq = 0
            }
            if refFreq > 0 {
                for mult in [2, 3, 4] {
                    let corrected = frequency * Float(mult)
                    let cents = abs(1200.0 * Float(log2(Double(corrected / refFreq))))
                    if cents < 70.0 {
                        inputFrequency = corrected
                        break
                    }
                }
            }
        }

        // ── Step 2: EMA on corrected frequency ──────────────────────────────────
        if inputFrequency > 0 && confidence > 0.5 {
            smoothedFrequency = smoothedFrequency == 0
                ? inputFrequency
                : alpha * inputFrequency + (1 - alpha) * smoothedFrequency
        }

        switch state {

        // ── SILENT ──────────────────────────────────────────────────────────────
        case .silent:
            releaseCount = 0
            let validPitch = smoothedFrequency > 0 && confidence > midiConfig.confidenceThreshold
            let loudEnough = rms > midiConfig.onsetThreshold

            guard validPitch && loudEnough else {
                onsetCount = 0
                onsetNote = 0
                return
            }

            let (q, _) = scaleQuantizer.quantize(frequency: smoothedFrequency)
            let note = UInt8(max(0, min(127, q)))

            if note == onsetNote {
                onsetCount += 1
            } else {
                onsetNote = note
                onsetCount = 1
            }

            guard onsetCount >= 3 else { return }  // ~9ms debounce — enough to reject noise spikes

            lastBend = 8192
            midiEngine.sendPitchBend(value: 8192, channel: channel)
            midiEngine.sendNoteOn(note: onsetNote, velocity: velocityFromRMS(rms), channel: channel)
            state = .sounding(currentNote: onsetNote)
            smoothedFrequency = frequency  // re-anchor to actual onset pitch
            onsetCount = 0
            noteChangeCount = 0
            noteChangePending = 0

        // ── SOUNDING ────────────────────────────────────────────────────────────
        case .sounding(let currentNote):

            // Release condition:
            // Primary — confidence collapses (user stopped singing, even with ambient noise)
            // Secondary — RMS drops below threshold
            // Either one counts. A brief dip is forgiven by the holdoff counter.
            let confRelease = confidence < midiConfig.confidenceThreshold * 0.60
            let rmsRelease  = rms < midiConfig.releaseThreshold

            if confRelease || rmsRelease {
                releaseCount += 1
                if releaseCount >= midiConfig.releaseHoldFrames {
                    midiEngine.sendNoteOff(note: currentNote, channel: channel)
                    midiEngine.sendPitchBend(value: 8192, channel: channel)
                    state = .silent
                    smoothedFrequency = 0
                    lastBend = 8192
                    onsetCount = 0
                    noteChangeCount = 0
                    noteChangePending = 0
                }
                // Don't update pitch or expression while coasting toward release
                return
            } else {
                releaseCount = 0
            }

            guard smoothedFrequency > 0 else { return }

            // Deviation in semitones from the currently sounding note
            let exactNote = Float(69.0 + 12.0 * log2(Double(smoothedFrequency) / 440.0))
            let deviation = exactNote - Float(currentNote)

            // ── Pitch bend with dead zone ───────────────────────────────────────
            let deadZone = midiConfig.pitchBendDeadZoneSemitones
            let targetBend: UInt16
            if abs(deviation) < deadZone {
                targetBend = 8192
            } else {
                let adj = deviation > 0 ? deviation - deadZone : deviation + deadZone
                targetBend = pitchBendValue(semitoneOffset: adj)
            }

            // Light IIR smoothing on bend to prevent stepping
            let newBend = UInt16((Int(lastBend) * 2 + Int(targetBend)) / 3)
            if newBend != lastBend {
                midiEngine.sendPitchBend(value: newBend, channel: channel)
                lastBend = newBend
            }

            // ── Note change ─────────────────────────────────────────────────────
            if !midiConfig.glideMode && abs(deviation) >= midiConfig.retriggerSemitoneThreshold {
                let (q, _) = scaleQuantizer.quantize(frequency: smoothedFrequency)
                let newNote = UInt8(max(0, min(127, q)))
                guard newNote != currentNote else {
                    noteChangeCount = 0
                    noteChangePending = 0
                    return
                }

                if newNote == noteChangePending {
                    noteChangeCount += 1
                } else {
                    noteChangePending = newNote
                    noteChangeCount = 1
                }

                if noteChangeCount >= midiConfig.retriggerDebounceFrames {
                    midiEngine.sendNoteOff(note: currentNote, channel: channel)
                    midiEngine.sendPitchBend(value: 8192, channel: channel)
                    midiEngine.sendNoteOn(note: newNote, velocity: velocityFromRMS(rms), channel: channel)
                    state = .sounding(currentNote: newNote)
                    lastBend = 8192
                    noteChangeCount = 0
                    noteChangePending = 0
                }
            } else {
                noteChangeCount = 0
                noteChangePending = 0
            }

            // ── Expression CC 11 ────────────────────────────────────────────────
            if midiConfig.sendExpression {
                let expr = UInt8(min(127, max(0, Int(rms * midiConfig.velocitySensitivity * 0.4))))
                midiEngine.sendCC(controller: 11, value: expr, channel: channel)
            }
        }
    }

    private func pitchBendValue(semitoneOffset: Float) -> UInt16 {
        let range = Float(midiConfig.pitchBendRangeSemitones)
        let clamped = max(-range, min(range, semitoneOffset))
        let value = 8192.0 + (clamped / range) * 8191.0
        return UInt16(max(0, min(16383, Int(value.rounded()))))
    }

    private func velocityFromRMS(_ rms: Float) -> UInt8 {
        UInt8(min(127, max(1, Int(rms * midiConfig.velocitySensitivity))))
    }
}
