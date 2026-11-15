import SwiftUI
import UIKit

extension UIColor {
    convenience init(hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}

extension Color {
    init(light: UInt32, dark: UInt32) {
        self.init(uiColor: UIColor { $0.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light) })
    }
}

/// Tokens from the "Shoppy / The quiet fitting room" foundations frame.
enum Theme {
    static let ivory = Color(light: 0xF6F4EF, dark: 0x171717)
    static let ink = Color(light: 0x171717, dark: 0xF6F4EF)
    static let onInk = Color(light: 0xFFFFFF, dark: 0x171717)
    static let muted = Color(light: 0x716E67, dark: 0xB8B9B0)
    static let line = Color(light: 0xE2DFD6, dark: 0x34362F)
    static let card = Color(light: 0xFFFFFF, dark: 0x242620)
    static let studio = Color(light: 0xEAE7DF, dark: 0x272B24)
    static let lime = Color(light: 0xD5EF77, dark: 0xD5EF77)
    static let onLime = Color(light: 0x171717, dark: 0x171717)
    static let banner = Color(light: 0xEAF0D8, dark: 0x343D24)
    static let warn = Color(light: 0x8A5416, dark: 0xE0A85C)
    static let warnFill = Color(light: 0xF3E9D9, dark: 0x3A2F1F)
    static let error = Color(light: 0xA53329, dark: 0xE8776C)

    static let margin: CGFloat = 24
    static let cardRadius: CGFloat = 18
    static let cardPadding: CGFloat = 16
    static let spacing: CGFloat = 12
    static let buttonHeight: CGFloat = 54
}
