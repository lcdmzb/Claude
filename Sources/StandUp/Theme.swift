import SwiftUI
import AppKit

extension Color {
    /// 自动跟随浅色 / 深色外观的颜色
    static func adaptive(light: NSColor, dark: NSColor) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let match = appearance.bestMatch(from: [.aqua, .darkAqua])
            return match == .darkAqua ? dark : light
        })
    }

    static func hex(_ value: UInt32, alpha: CGFloat = 1) -> Color {
        Color(
            .sRGB,
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255,
            opacity: alpha
        )
    }
}

private func ns(_ value: UInt32, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(
        srgbRed: CGFloat((value >> 16) & 0xFF) / 255,
        green: CGFloat((value >> 8) & 0xFF) / 255,
        blue: CGFloat(value & 0xFF) / 255,
        alpha: alpha
    )
}

enum Theme {
    // 主色：薄荷绿 → 湖蓝，柔和且有「起身、呼吸」的联想
    static let accent = Color.adaptive(light: ns(0x1FA97F), dark: ns(0x35D6A4))
    static let accentSoft = Color.adaptive(light: ns(0x1FA97F, 0.14), dark: ns(0x35D6A4, 0.20))
    static let accentSecondary = Color.adaptive(light: ns(0x2E86C1), dark: ns(0x53B0EA))
    static let warning = Color.adaptive(light: ns(0xE08A2C), dark: ns(0xF0A84E))

    static let textPrimary = Color.adaptive(light: ns(0x18211E), dark: ns(0xF2F6F4))
    static let textSecondary = Color.adaptive(light: ns(0x18211E, 0.60), dark: ns(0xF2F6F4, 0.62))
    static let textTertiary = Color.adaptive(light: ns(0x18211E, 0.38), dark: ns(0xF2F6F4, 0.40))

    static let card = Color.adaptive(light: ns(0xFFFFFF, 0.86), dark: ns(0x1B2320, 0.72))
    static let cardBorder = Color.adaptive(light: ns(0x18211E, 0.07), dark: ns(0xFFFFFF, 0.09))
    static let track = Color.adaptive(light: ns(0x18211E, 0.08), dark: ns(0xFFFFFF, 0.10))

    /// 主界面背景渐变
    static var backgroundGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color.adaptive(light: ns(0xEAF7F1), dark: ns(0x101614)),
                Color.adaptive(light: ns(0xF4F7FB), dark: ns(0x121A20)),
                Color.adaptive(light: ns(0xFBF3EC), dark: ns(0x161513))
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var ringGradient: AngularGradient {
        AngularGradient(
            colors: [accent, accentSecondary, accent],
            center: .center,
            startAngle: .degrees(0),
            endAngle: .degrees(360)
        )
    }

    /// 打卡热力图的等级配色（0 = 未打卡）
    static func heatColor(level: Int) -> Color {
        switch level {
        case 1: return Color.adaptive(light: ns(0x1FA97F, 0.25), dark: ns(0x35D6A4, 0.25))
        case 2: return Color.adaptive(light: ns(0x1FA97F, 0.45), dark: ns(0x35D6A4, 0.45))
        case 3: return Color.adaptive(light: ns(0x1FA97F, 0.70), dark: ns(0x35D6A4, 0.70))
        case 4: return Color.adaptive(light: ns(0x1FA97F, 1.00), dark: ns(0x35D6A4, 0.95))
        default: return Color.adaptive(light: ns(0x18211E, 0.05), dark: ns(0xFFFFFF, 0.06))
        }
    }
}

// MARK: - 通用卡片容器

struct Card<Content: View>: View {
    var padding: CGFloat = 20
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Theme.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Theme.cardBorder, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.06), radius: 14, x: 0, y: 6)
    }
}

// MARK: - 主按钮样式

struct PrimaryButtonStyle: ButtonStyle {
    var tint: Color = Theme.accent
    var wide: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, wide ? 28 : 18)
            .padding(.vertical, 10)
            .frame(maxWidth: wide ? .infinity : nil)
            .background(
                Capsule(style: .continuous)
                    .fill(tint.opacity(configuration.isPressed ? 0.78 : 1))
            )
            .shadow(color: tint.opacity(0.35), radius: configuration.isPressed ? 3 : 9, y: 3)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct SoftButtonStyle: ButtonStyle {
    var tint: Color = Theme.textPrimary

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(tint)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                Capsule(style: .continuous)
                    .fill(Theme.track.opacity(configuration.isPressed ? 1.6 : 1))
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
