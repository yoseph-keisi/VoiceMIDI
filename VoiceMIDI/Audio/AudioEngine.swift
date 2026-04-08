import Foundation
import AVFoundation
import CoreAudio
import Combine

class AudioEngine: ObservableObject {
    private let engine = AVAudioEngine()
    private let pitchDetector: PitchDetector
    private var accumulationBuffer: [Float]
    private var accumulationIndex: Int = 0
    private let yinBufferSize = 2048
    private let sampleRate: Int32 = 44100
    private let tapBufferSize: AVAudioFrameCount = 128

    // Peak-follower RMS: fast attack, slow release — prevents release from firing on transient dips
    private var smoothedRMS: Float = 0
    private let rmsAttack: Float = 1.0      // Instant attack
    private let rmsRelease: Float = 0.92    // ~40ms release at 128-sample callbacks

    @Published var currentFrequency: Float = 0
    @Published var confidence: Float = 0
    @Published var rmsAmplitude: Float = 0

    var onPitchDetected: ((Float, Float, Float) -> Void)?  // freq, confidence, smoothedRMS

    init() {
        pitchDetector = PitchDetector(bufferSize: Int32(yinBufferSize), threshold: 0.12)
        accumulationBuffer = [Float](repeating: 0, count: yinBufferSize)
    }

    func start(deviceID: AudioDeviceID?) {
        stop()

        if let deviceID = deviceID {
            setInputDevice(deviceID)
        }

        let inputNode = engine.inputNode
        let inputFormat = inputNode.inputFormat(forBus: 0)

        let monoFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: Double(sampleRate),
            channels: 1,
            interleaved: false
        ) ?? inputFormat

        inputNode.installTap(onBus: 0, bufferSize: tapBufferSize, format: monoFormat) { [weak self] buffer, _ in
            self?.processTapBuffer(buffer)
        }

        do {
            try engine.start()
        } catch {
            print("AudioEngine failed to start: \(error)")
        }
    }

    func stop() {
        engine.inputNode.removeTap(onBus: 0)
        if engine.isRunning {
            engine.stop()
        }
        smoothedRMS = 0
    }

    private func processTapBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData else { return }
        let frameCount = Int(buffer.frameLength)
        let samples = channelData[0]

        // Compute raw RMS of this 128-sample chunk
        var rawRMS: Float = 0
        for i in 0..<frameCount {
            rawRMS += samples[i] * samples[i]
        }
        rawRMS = sqrtf(rawRMS / Float(frameCount))

        // Peak follower: attack fast, release slow
        // This prevents a single quiet frame from prematurely releasing a note
        if rawRMS >= smoothedRMS {
            smoothedRMS = rawRMS
        } else {
            smoothedRMS = rmsRelease * smoothedRMS
        }

        // Append to sliding ring buffer
        for i in 0..<frameCount {
            accumulationBuffer[accumulationIndex % yinBufferSize] = samples[i]
            accumulationIndex += 1
        }

        guard accumulationIndex >= yinBufferSize else { return }

        // Build contiguous snapshot for YIN
        let startIdx = accumulationIndex % yinBufferSize
        var snapshot = [Float](repeating: 0, count: yinBufferSize)
        for i in 0..<yinBufferSize {
            snapshot[i] = accumulationBuffer[(startIdx + i) % yinBufferSize]
        }

        let (freq, conf) = snapshot.withUnsafeBufferPointer { ptr in
            pitchDetector.detect(audioBuffer: ptr.baseAddress!, sampleRate: sampleRate)
        }

        let detectedFreq = conf > 0.5 ? freq : 0
        let rmsOut = smoothedRMS

        DispatchQueue.main.async { [weak self] in
            self?.currentFrequency = detectedFreq
            self?.confidence = conf
            self?.rmsAmplitude = rmsOut
        }

        onPitchDetected?(detectedFreq, conf, rmsOut)
    }

    private func setInputDevice(_ deviceID: AudioDeviceID) {
        var id = deviceID
        let audioUnit = engine.inputNode.audioUnit!
        AudioUnitSetProperty(
            audioUnit,
            kAudioOutputUnitProperty_CurrentDevice,
            kAudioUnitScope_Global,
            0,
            &id,
            UInt32(MemoryLayout<AudioDeviceID>.size)
        )
    }
}
