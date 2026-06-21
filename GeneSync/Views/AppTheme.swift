import SwiftUI

enum GeneSyncTheme {
    static let background = Color(hex: 0xFFF8F6)
    static let surface = Color(hex: 0xFFFFFF)
    static let surfaceLow = Color(hex: 0xFFF0EE)
    static let surfaceHigh = Color(hex: 0xFAE3DF)
    static let surfaceHighest = Color(hex: 0xF5DDDA)
    static let text = Color(hex: 0x251917)
    static let secondaryText = Color(hex: 0x58413E)
    static let primary = Color(hex: 0x660100)
    static let primaryDark = Color(hex: 0x3F0000)
    static let secondary = Color(hex: 0x595D78)
    static let outline = Color(hex: 0xDFBFBA)
    static let error = Color(hex: 0xBA1A1A)
    static let success = Color(hex: 0x0F7B4A)
    static let warning = Color(hex: 0xA86A00)
    static let monoBackground = Color(hex: 0xFFF8F6)

    static func headline(_ size: CGFloat = 28) -> Font {
        .system(size: size, weight: .bold, design: .default)
    }

    static func body(_ size: CGFloat = 15, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .default)
    }

    static func mono(_ size: CGFloat = 13, weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
}

extension Color {
    init(hex: UInt, alpha: Double = 1) {
        let red = Double((hex >> 16) & 0xFF) / 255
        let green = Double((hex >> 8) & 0xFF) / 255
        let blue = Double(hex & 0xFF) / 255
        self.init(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
    }
}

extension Double {
    var percentageString: String {
        String(format: "%.1f%%", self)
    }
}

extension Date {
    var shortGeneSyncFormat: String {
        formatted(date: .abbreviated, time: .shortened)
    }
}
