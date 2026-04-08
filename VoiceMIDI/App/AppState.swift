import Foundation
import Combine
import CoreAudio

class AppState: ObservableObject {
    let audioEngine: AudioEngine
    let midiEngine: MIDIEngine
    let noteTracker: NoteTracker
    let scaleQuantizer: ScaleQuantizer
    let midiConfig: MIDIConfig
    let deviceManager = AudioDeviceManager()

    @Published var selectedDevice: AudioDeviceManager.AudioDevice?
    @Published var availableDevices: [AudioDeviceManager.AudioDevice] = []
    @Published var currentNoteName: String = "—"
    @Published var currentCentsOffset: Int = 0
    @Published var isActive: Bool = false

    private var cancellables: Set<AnyCancellable> = []

    init() {
        let config = MIDIConfig()
        let quantizer = ScaleQuantizer()
        let midi = MIDIEngine()
        let audio = AudioEngine()
        let tracker = NoteTracker(scaleQuantizer: quantizer, midiEngine: midi, midiConfig: config)

        self.midiConfig = config
        self.scaleQuantizer = quantizer
        self.midiEngine = midi
        self.audioEngine = audio
        self.noteTracker = tracker

        // Wire audio → note tracker
        audio.onPitchDetected = { [weak self] freq, confidence, rms in
            guard let self = self else { return }
            self.noteTracker.process(frequency: freq, confidence: confidence, rms: rms)
            DispatchQueue.main.async {
                self.updateNoteDisplay(frequency: freq)
            }
        }

        // Refresh device list
        availableDevices = AudioDeviceManager.listInputDevices()

        // Auto-select default device
        if let defaultID = AudioDeviceManager.getDefaultInputDevice() {
            selectedDevice = availableDevices.first { $0.id == defaultID } ?? availableDevices.first
        } else {
            selectedDevice = availableDevices.first
        }

        // React to device selection changes
        $selectedDevice
            .dropFirst()
            .sink { [weak self] device in
                guard let self = self, self.isActive else { return }
                self.audioEngine.stop()
                self.audioEngine.start(deviceID: device?.id)
            }
            .store(in: &cancellables)
    }

    func start() {
        audioEngine.start(deviceID: selectedDevice?.id)
        isActive = true
    }

    func stop() {
        audioEngine.stop()
        // Send all-notes-off on all channels to prevent hanging notes
        for ch in 0..<16 {
            midiEngine.sendAllNotesOff(channel: UInt8(ch))
        }
        isActive = false
    }

    func refreshDevices() {
        availableDevices = AudioDeviceManager.listInputDevices()
    }

    private func updateNoteDisplay(frequency: Float) {
        guard frequency > 0 else {
            currentNoteName = "—"
            currentCentsOffset = 0
            return
        }

        let exactNote = 69.0 + 12.0 * log2(Double(frequency) / 440.0)
        let midiNote = Int(exactNote.rounded())
        let cents = Int((exactNote - Double(midiNote)) * 100.0)

        let noteNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
        let pitchClass = ((midiNote % 12) + 12) % 12
        let octave = (midiNote / 12) - 1
        currentNoteName = "\(noteNames[pitchClass])\(octave)"
        currentCentsOffset = cents
    }
}
