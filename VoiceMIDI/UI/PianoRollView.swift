import SwiftUI

struct PianoRollView: View {
    @EnvironmentObject var appState: AppState

    // Display range: C2 (36) to C6 (84)
    private let startNote = 36
    private let endNote   = 84

    // White key indices within an octave
    private let whiteKeyPitchClasses: [Int] = [0, 2, 4, 5, 7, 9, 11]
    private let whiteKeyNames: [String]     = ["C", "D", "E", "F", "G", "A", "B"]

    // Black key offsets within a 7-white-key octave (in units of white key widths)
    // Position is the offset from the left edge of the octave
    private let blackKeyOffsets: [Int: CGFloat] = [
        1:  0.67,   // C#
        3:  1.67,   // D#
        6:  3.67,   // F#
        8:  4.67,   // G#
        10: 5.67    // A#
    ]

    private var whiteNotesInRange: [Int] {
        (startNote...endNote).filter { whiteKeyPitchClasses.contains(($0 % 12 + 12) % 12) }
    }

    var body: some View {
        GeometryReader { geo in
            let whiteCount = whiteNotesInRange.count
            let whiteW = whiteCount > 0 ? geo.size.width / CGFloat(whiteCount) : 24
            let blackW = whiteW * 0.6
            let blackH = geo.size.height * 0.62

            ZStack(alignment: .topLeading) {
                // White keys
                HStack(spacing: 1) {
                    ForEach(whiteNotesInRange, id: \.self) { note in
                        let pc = (note % 12 + 12) % 12
                        let isEnabled = isNoteEnabled(note)
                        let nameIndex = whiteKeyPitchClasses.firstIndex(of: pc) ?? 0

                        ZStack(alignment: .bottom) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(isEnabled ? Theme.accent : Theme.pianoWhiteIdle)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 3)
                                        .stroke(Color.black.opacity(0.3), lineWidth: 0.5)
                                )

                            if pc == 0 {
                                Text(whiteKeyNames[nameIndex])
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundColor(isEnabled ? Theme.background : Theme.textSecondary)
                                    .padding(.bottom, 4)
                            }
                        }
                        .onTapGesture {
                            toggleNote(note)
                        }
                    }
                }

                // Black keys overlay
                ForEach(Array(blackKeysInRange().enumerated()), id: \.element.note) { _, blackKey in
                    let isEnabled = isNoteEnabled(blackKey.note)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(isEnabled ? Theme.accent : Theme.pianoBlackIdle)
                        .frame(width: blackW, height: blackH)
                        .offset(x: blackKey.xOffset * (whiteW + 1) - blackW / 2, y: 0)
                        .onTapGesture {
                            toggleNote(blackKey.note)
                        }
                }

                // Pitch indicator overlay
                PitchIndicatorView(
                    frequency: appState.audioEngine.currentFrequency,
                    pianoStartNote: startNote,
                    pianoEndNote: endNote,
                    totalWidth: geo.size.width
                )
            }
        }
        .frame(height: 120)
    }

    private func isNoteEnabled(_ note: Int) -> Bool {
        let pc = (note % 12 + 12) % 12
        let relative = ((pc - appState.scaleQuantizer.rootNote) + 12) % 12
        return appState.scaleQuantizer.enabledNotes.contains(relative)
    }

    private func toggleNote(_ note: Int) {
        let pc = (note % 12 + 12) % 12
        let relative = ((pc - appState.scaleQuantizer.rootNote) + 12) % 12
        if appState.scaleQuantizer.enabledNotes.contains(relative) {
            appState.scaleQuantizer.enabledNotes.remove(relative)
        } else {
            appState.scaleQuantizer.enabledNotes.insert(relative)
        }
    }

    private struct BlackKeyInfo {
        let note: Int
        let xOffset: CGFloat
    }

    private func blackKeysInRange() -> [BlackKeyInfo] {
        var result: [BlackKeyInfo] = []
        var whiteIndex: CGFloat = 0

        for note in startNote...endNote {
            let pc = (note % 12 + 12) % 12
            if whiteKeyPitchClasses.contains(pc) {
                // Check if the next black key is above this white key
                if let offset = blackKeyOffsets[pc] {
                    // black key note = next chromatic up
                    let blackNote = note + 1
                    if blackNote <= endNote {
                        result.append(BlackKeyInfo(note: blackNote, xOffset: whiteIndex + offset))
                    }
                }
                whiteIndex += 1
            }
        }
        return result
    }
}
