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

    @Published var currentFrequency: Float = 0
    @Published var confidence: Float = 0
    @Published var rmsAmplitude: Float = 0

    var onPitchDetected: ((Float, Float, Float) -> Void)?  // freq, confidence, rms

    init() {
        pitchDetector = PitchDetector(bufferSize: Int32(yinBufferSize), threshold: 0.12)
        accumulationBuffer = [Float](repeating: 0, count: yinBufferSize)
    }

    func start(deviceID: AudioDeviceID?) {
        stop()

        // Set input device if specified
        if let deviceID = deviceID {
            setInputDevice(deviceID)
        }

        let inputNode = engine.inputNode
        let inputFormat = inputNode.inputFormat(forBus: 0)

        // Request mono Float32 at 44100 Hz
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
    }

    private func processTapBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData else { return }
        let frameCount = Int(buffer.frameLength)
        let samples = channelData[0]

        // Compute RMS of the incoming 128-sample chunk
        var rms: Float = 0
        for i in 0..<frameCount {
            rms += samples[i] * samples[i]
        }
        rms = sqrtf(rms / Float(frameCount))

        // Append to sliding accumulation buffer (ring buffer)
        for i in 0..<frameCount {
            accumulationBuffer[accumulationIndex % yinBufferSize] = samples[i]
            accumulationIndex += 1
        }

        // Once we have at least yinBufferSize samples, run detection on every callback
        if accumulationIndex >= yinBufferSize {
            // Build a contiguous snapshot of the accumulation buffer in order
            let startIdx = accumulationIndex % yinBufferSize
            var snapshot = [Float](repeating: 0, count: yinBufferSize)
            for i in 0..<yinBufferSize {
                snapshot[i] = accumulationBuffer[(startIdx + i) % yinBufferSize]
            }

            let (freq, conf) = snapshot.withUnsafeBufferPointer { ptr in
                pitchDetector.detect(audioBuffer: ptr.baseAddress!, sampleRate: sampleRate)
            }

            let detectedFreq = conf > 0.5 ? freq : 0
            let detectedConf = conf

            DispatchQueue.main.async { [weak self] in
                self?.currentFrequency = detectedFreq
                self?.confidence = detectedConf
                self?.rmsAmplitude = rms
            }

            onPitchDetected?(detectedFreq, detectedConf, rms)
        }
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
