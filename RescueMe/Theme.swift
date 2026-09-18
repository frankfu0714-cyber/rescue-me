import SwiftUI

enum Theme {
    static let accent = Color(red: 0.902, green: 0.220, blue: 0.220)   // rescue red
    static let callGreen = Color(red: 0.20, green: 0.78, blue: 0.35)
    static let callRed = Color(red: 0.95, green: 0.25, blue: 0.25)
    static let inCallBackground = Color(red: 0.08, green: 0.09, blue: 0.12)
    static let inCallButtonBg = Color(white: 0.22)

    static let presetColors: [String] = Contact.presetColors
}

extension Color {
    init(hex: String) {
        let h = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var uint: UInt64 = 0
        Scanner(string: h).scanHexInt64(&uint)
        let a, r, g, b: UInt64
        switch h.count {
        case 3:  (a, r, g, b) = (255, (uint >> 8) * 17, (uint >> 4 & 0xF) * 17, (uint & 0xF) * 17)
        case 6:  (a, r, g, b) = (255, uint >> 16, uint >> 8 & 0xFF, uint & 0xFF)
        case 8:  (a, r, g, b) = (uint >> 24, uint >> 16 & 0xFF, uint >> 8 & 0xFF, uint & 0xFF)
        default: (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB, red: Double(r)/255, green: Double(g)/255, blue: Double(b)/255, opacity: Double(a)/255)
    }
}
