import SwiftUI

enum Theme {
    // MARK: - Colors
    static let background       = Color(hex: "#0D0D0F")
    static let surface          = Color(hex: "#1A1A1E")
    static let accent            = Color(hex: "#E8A84C")
    static let textPrimary       = Color(hex: "#E8E6E3")
    static let textSecondary     = Color(hex: "#8A8A8E")
    static let pianoWhiteIdle    = Color(hex: "#D4D2CF")
    static let pianoBlackIdle    = Color(hex: "#2A2A2E")

    // MARK: - Corner Radii
    static let panelRadius: CGFloat = 8
    static let controlRadius: CGFloat = 4

    // MARK: - Spacing
    static let padding: CGFloat = 12
    static let sectionSpacing: CGFloat = 16
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        let scanner = Scanner(string: hex)
        var rgb: UInt64 = 0
        scanner.scanHexInt64(&rgb)
        let r = Double((rgb >> 16) & 0xFF) / 255.0
        let g = Double((rgb >> 8)  & 0xFF) / 255.0
        let b = Double( rgb        & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}
