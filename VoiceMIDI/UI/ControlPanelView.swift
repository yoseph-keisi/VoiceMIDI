import SwiftUI

struct ControlPanelView: View {
    @EnvironmentObject var appState: AppState

    private let bendRangeOptions = [1, 2, 7, 12, 24]
    private let noteNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 20) {
                // Sensitivity (onset threshold)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Sensitivity")
                        .font(.system(size: 11))
                        .foregroundColor(Theme.textSecondary)
                    Slider(
                        value: Binding(
                            get: { Double(appState.midiConfig.onsetThreshold) },
                            set: { appState.midiConfig.onsetThreshold = Float($0) }
                        ),
                        in: 0.001...0.1
                    )
                    .accentColor(Theme.accent)
                    .frame(width: 120)
                }

                // Confidence threshold
                VStack(alignment: .leading, spacing: 4) {
                    Text("Confidence")
                        .font(.system(size: 11))
                        .foregroundColor(Theme.textSecondary)
                    Slider(
                        value: Binding(
                            get: { Double(appState.midiConfig.confidenceThreshold) },
                            set: { appState.midiConfig.confidenceThreshold = Float($0) }
                        ),
                        in: 0.5...1.0
                    )
                    .accentColor(Theme.accent)
                    .frame(width: 120)
                }

                Divider().frame(height: 40).background(Theme.textSecondary.opacity(0.3))

                // Pitch bend range
                VStack(alignment: .leading, spacing: 4) {
                    Text("Bend Range")
                        .font(.system(size: 11))
                        .foregroundColor(Theme.textSecondary)
                    Picker("", selection: $appState.midiConfig.pitchBendRangeSemitones) {
                        ForEach(bendRangeOptions, id: \.self) { v in
                            Text("±\(v)").tag(v)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 160)
                }

                Divider().frame(height: 40).background(Theme.textSecondary.opacity(0.3))

                // Glide mode toggle
                VStack(alignment: .leading, spacing: 4) {
                    Text("Glide")
                        .font(.system(size: 11))
                        .foregroundColor(Theme.textSecondary)
                    Toggle("", isOn: $appState.midiConfig.glideMode)
                        .toggleStyle(SwitchToggleStyle(tint: Theme.accent))
                        .labelsHidden()
                }

                // Expression CC toggle
                VStack(alignment: .leading, spacing: 4) {
                    Text("Expr CC11")
                        .font(.system(size: 11))
                        .foregroundColor(Theme.textSecondary)
                    Toggle("", isOn: $appState.midiConfig.sendExpression)
                        .toggleStyle(SwitchToggleStyle(tint: Theme.accent))
                        .labelsHidden()
                }

                Divider().frame(height: 40).background(Theme.textSecondary.opacity(0.3))

                // MIDI Channel
                VStack(alignment: .leading, spacing: 4) {
                    Text("MIDI Ch")
                        .font(.system(size: 11))
                        .foregroundColor(Theme.textSecondary)
                    Stepper(
                        "\(Int(appState.midiConfig.midiChannel) + 1)",
                        value: Binding(
                            get: { Int(appState.midiConfig.midiChannel) },
                            set: { appState.midiConfig.midiChannel = UInt8($0) }
                        ),
                        in: 0...15
                    )
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundColor(Theme.textPrimary)
                }

                // Root note
                VStack(alignment: .leading, spacing: 4) {
                    Text("Root")
                        .font(.system(size: 11))
                        .foregroundColor(Theme.textSecondary)
                    Picker("", selection: $appState.scaleQuantizer.rootNote) {
                        ForEach(0..<12, id: \.self) { i in
                            Text(noteNames[i]).tag(i)
                        }
                    }
                    .frame(width: 70)
                }

                Spacer()

                // Pitch bend range note for Logic
                VStack(alignment: .leading, spacing: 2) {
                    Text("Set Logic pitch bend to ±\(appState.midiConfig.pitchBendRangeSemitones) semitones")
                        .font(.system(size: 10))
                        .foregroundColor(Theme.textSecondary.opacity(0.7))
                }
            }
            .padding(.horizontal, Theme.padding)
            .padding(.vertical, 8)
        }
        .background(Theme.surface)
        .cornerRadius(Theme.panelRadius)
    }
}
