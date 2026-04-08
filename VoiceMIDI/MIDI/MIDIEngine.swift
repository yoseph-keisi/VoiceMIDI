import Foundation
import CoreMIDI

class MIDIEngine {
    private var midiClient: MIDIClientRef = 0
    private var midiSource: MIDIEndpointRef = 0

    init() {
        var status = MIDIClientCreateWithBlock("VoiceMIDI Client" as CFString, &midiClient) { notification in
            // Handle MIDI system notifications if needed
        }
        guard status == noErr else {
            print("Failed to create MIDI client: \(status)")
            return
        }

        status = MIDISourceCreateWithProtocol(midiClient, "VoiceMIDI" as CFString, ._1_0, &midiSource)
        guard status == noErr else {
            print("Failed to create MIDI source: \(status)")
            return
        }
    }

    deinit {
        if midiClient != 0 {
            MIDIClientDispose(midiClient)
        }
    }

    func sendNoteOn(note: UInt8, velocity: UInt8, channel: UInt8 = 0) {
        sendMIDI([0x90 | (channel & 0x0F), note & 0x7F, velocity & 0x7F])
    }

    func sendNoteOff(note: UInt8, channel: UInt8 = 0) {
        sendMIDI([0x80 | (channel & 0x0F), note & 0x7F, 0x00])
    }

    /// value: 0–16383, center = 8192
    func sendPitchBend(value: UInt16, channel: UInt8 = 0) {
        let clamped = min(value, 16383)
        let lsb = UInt8(clamped & 0x7F)
        let msb = UInt8((clamped >> 7) & 0x7F)
        sendMIDI([0xE0 | (channel & 0x0F), lsb, msb])
    }

    func sendCC(controller: UInt8, value: UInt8, channel: UInt8 = 0) {
        sendMIDI([0xB0 | (channel & 0x0F), controller & 0x7F, value & 0x7F])
    }

    func sendAllNotesOff(channel: UInt8 = 0) {
        sendCC(controller: 123, value: 0, channel: channel)
    }

    private func sendMIDI(_ bytes: [UInt8]) {
        var packetList = MIDIPacketList()
        var packet = MIDIPacketListInit(&packetList)
        packet = MIDIPacketListAdd(&packetList, 1024, packet, 0, bytes.count, bytes)
        MIDIReceived(midiSource, &packetList)
    }
}
