import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedPreset: Scale.Preset = .chromatic

    var body: some View {
        VStack(spacing: 0) {
            // 1. Header bar
            headerBar

            Divider().background(Theme.textSecondary.opacity(0.2))

            // 2. Piano roll
            PianoRollView()
                .padding(.horizontal, Theme.padding)
                .padding(.vertical, 8)

            Divider().background(Theme.textSecondary.opacity(0.2))

            // 3. Scale preset bar
            scalePresetBar

            Divider().background(Theme.textSecondary.opacity(0.2))

            // 4. Control panel
            ControlPanelView()
                .padding(.horizontal, Theme.padding)
                .padding(.vertical, 6)

            Divider().background(Theme.textSecondary.opacity(0.2))

            // 5. Status footer
            statusFooter
        }
        .background(Theme.background)
        .frame(minWidth: 700, minHeight: 500)
    }

    // MARK: - Header Bar

    private var headerBar: some View {
        HStack {
            Text("VoiceMIDI")
                .font(.system(size: 16, weight: .semibold, design: .default))
                .foregroundColor(Theme.textPrimary)

            Spacer()

            // Device picker
            Picker("", selection: $appState.selectedDevice) {
                ForEach(appState.availableDevices) { device in
                    Text(device.name).tag(Optional(device))
                }
            }
            .frame(width: 200)
            .onAppear { appState.refreshDevices() }

            // Latency readout
            Text("~3ms")
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(Theme.textSecondary)
                .padding(.leading, 8)
        }
        .padding(.horizontal, Theme.padding)
        .padding(.vertical, 10)
        .background(Theme.surface)
    }

    // MARK: - Scale Preset Bar

    private var scalePresetBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Scale.Preset.allCases) { preset in
                    if preset != .custom {
                        presetChip(preset)
                    }
                }
                // Custom chip (read-only indicator)
                if selectedPreset == .custom {
                    Text("Custom")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Theme.background)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Theme.accent)
                        .cornerRadius(Theme.controlRadius)
                }
            }
            .padding(.horizontal, Theme.padding)
            .padding(.vertical, 8)
        }
    }

    private func presetChip(_ preset: Scale.Preset) -> some View {
        let isSelected = selectedPreset == preset
        return Button(action: {
            selectedPreset = preset
            appState.scaleQuantizer.applyPreset(preset)
        }) {
            Text(preset.rawValue)
                .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                .foregroundColor(isSelected ? Theme.background : Theme.textPrimary)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(isSelected ? Theme.accent : Theme.surface)
                .cornerRadius(Theme.controlRadius)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Status Footer

    private var statusFooter: some View {
        HStack(spacing: 16) {
            // MIDI status
            HStack(spacing: 6) {
                Circle()
                    .fill(appState.isActive ? Color.green : Color.gray)
                    .frame(width: 8, height: 8)
                Text("MIDI: VoiceMIDI — \(appState.isActive ? "Active" : "Stopped")")
                    .font(.system(size: 12))
                    .foregroundColor(Theme.textSecondary)
            }

            Divider().frame(height: 16).background(Theme.textSecondary.opacity(0.3))

            // Current note
            HStack(spacing: 4) {
                Text(appState.currentNoteName)
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundColor(Theme.textPrimary)

                if appState.currentCentsOffset != 0 {
                    Text(appState.currentCentsOffset > 0 ? "+\(appState.currentCentsOffset)¢" : "\(appState.currentCentsOffset)¢")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(Theme.textSecondary)
                }
            }

            Divider().frame(height: 16).background(Theme.textSecondary.opacity(0.3))

            // Amplitude meter
            AmplitudeMeterView(amplitude: appState.audioEngine.rmsAmplitude)

            Spacer()

            // Start/Stop button
            Button(appState.isActive ? "Stop" : "Start") {
                if appState.isActive {
                    appState.stop()
                } else {
                    appState.start()
                }
            }
            .buttonStyle(.plain)
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(appState.isActive ? Theme.textSecondary : Theme.accent)
        }
        .padding(.horizontal, Theme.padding)
        .padding(.vertical, 8)
        .background(Theme.surface)
    }
}

// MARK: - Amplitude Meter

struct AmplitudeMeterView: View {
    let amplitude: Float
    private let barCount = 12

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<barCount, id: \.self) { i in
                let threshold = Float(i) / Float(barCount)
                Rectangle()
                    .fill(amplitude > threshold ? Theme.accent : Theme.pianoBlackIdle)
                    .frame(width: 4, height: 12)
                    .cornerRadius(1)
            }
        }
    }
}
