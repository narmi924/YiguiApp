import SwiftUI

extension Color {
    static let primary = Color(hex: "E8AD70") // 主要颜色（橙棕色）
    static let themeColor = Color(hex: "E8AD70") // 主题色
    static let background = Color.white // 背景色
    static let darkBrown = Color(hex: "704F38") // 深棕色
    static let textPrimary = Color.black // 主要文本颜色
    static let textSecondary = Color.black.opacity(0.4) // 次要文本颜色
}

// 从十六进制创建颜色的扩展
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: Double(a) / 255)
    }
} 