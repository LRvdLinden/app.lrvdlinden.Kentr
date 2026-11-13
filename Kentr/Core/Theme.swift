import SwiftUI
import UIKit

extension Color {
    /// Kleur met een aparte waarde voor licht en donker.
    init(light: UInt32, dark: UInt32) {
        func rgb(_ hex: UInt32) -> (CGFloat, CGFloat, CGFloat) {
            (CGFloat((hex >> 16) & 0xFF) / 255, CGFloat((hex >> 8) & 0xFF) / 255, CGFloat(hex & 0xFF) / 255)
        }
        let (lr, lg, lb) = rgb(light), (dr, dg, db) = rgb(dark)
        self.init(uiColor: UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(red: dr, green: dg, blue: db, alpha: 1)
                : UIColor(red: lr, green: lg, blue: lb, alpha: 1)
        })
    }

    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255)
    }
}

/// Huisstijl van Kentr: kentekengeel met donkerblauw.
enum Theme {
    /// Donkerblauw in licht, kentekengeel in donker (leesbaar op beide).
    static let accent = Color(light: 0x0B2A6F, dark: 0xF5C400)
    static let plateYellow = Color(hex: 0xF5C400)
    static let plateBlue = Color(hex: 0x003399)
    static let navy = Color(hex: 0x0B1F4B)
    static let navyDeep = Color(hex: 0x071436)
    static let ink = Color(hex: 0x111111)
    static let cardBackground = Color(light: 0xFFFFFF, dark: 0x1C1D26)
}

/// Weergave: Automatisch / Licht / Donker.
enum AppearanceSetting: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }
    var label: LocalizedStringKey {
        switch self { case .system: "Automatisch"; case .light: "Licht"; case .dark: "Donker" }
    }
    var colorScheme: ColorScheme? {
        switch self { case .system: nil; case .light: .light; case .dark: .dark }
    }
}
