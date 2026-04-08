import SwiftUI

struct PitchIndicatorView: View {
    let frequency: Float
    let pianoStartNote: Int   // Lowest MIDI note displayed
    let pianoEndNote: Int     // Highest MIDI note displayed
    let totalWidth: CGFloat

    private var xPosition: CGFloat? {
        guard frequency > 0 else { return nil }
        let exactNote = 69.0 + 12.0 * log2(Double(frequency) / 440.0)
        let range = Double(pianoEndNote - pianoStartNote)
        guard range > 0 else { return nil }
        let normalized = (exactNote - Double(pianoStartNote)) / range
        return CGFloat(normalized) * totalWidth
    }

    var body: some View {
        GeometryReader { geo in
            if let x = xPosition {
                ZStack {
                    // Soft glow
                    Rectangle()
                        .fill(Theme.accent.opacity(0.35))
                        .frame(width: 12, height: geo.size.height)
                        .blur(radius: 5)
                        .offset(x: x - 6)

                    // Sharp line
                    Rectangle()
                        .fill(Theme.accent)
                        .frame(width: 2, height: geo.size.height)
                        .offset(x: x - 1)
                }
                .animation(.linear(duration: 0.03), value: x)
            }
        }
        .allowsHitTesting(false)
    }
}
