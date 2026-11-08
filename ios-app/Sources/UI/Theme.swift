import SwiftUI

/// 配色与尺寸令牌。数值直接对齐 Android 端 `colors.xml` / `界面与间距规范.md`，
/// 两端放一起不该出现两种绿。
public enum Theme {

    public static let accent = Color(hex: 0x07C160)
    public static let badge = Color(hex: 0xFA5151)
    public static let link = Color(hex: 0x576B95)

    public static let pageMargin: CGFloat = 16
    public static let topBarHeight: CGFloat = 48
    public static let itemHeight: CGFloat = 68
    public static let fieldHeight: CGFloat = 44
    public static let cornerRadius: CGFloat = 12

    public static func pageBackground(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: 0x111111) : Color(hex: 0xEDEDED)
    }

    public static func cardBackground(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: 0x191919) : Color.white
    }

    public static func primaryText(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: 0xD6D6D6) : Color(hex: 0x191919)
    }

    public static func secondaryText(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: 0x7F7F7F) : Color(hex: 0x888888)
    }

    public static func divider(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: 0x2A2A2A) : Color(hex: 0xE5E5E5)
    }
}

public extension Color {
    init(hex: UInt32, alpha: Double = 1.0) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8) & 0xFF) / 255.0
        let b = Double(hex & 0xFF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: alpha)
    }
}

/// 顶栏：左边标题，右边图标按钮（对应 Android 的 page_title 48dp 栏）
public struct TopBar<Trailing: View>: View {
    let title: String
    let trailing: () -> Trailing

    public init(title: String, @ViewBuilder trailing: @escaping () -> Trailing) {
        self.title = title
        self.trailing = trailing
    }

    public var body: some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.primary)
            Spacer()
            trailing()
        }
        .padding(.horizontal, Theme.pageMargin)
        .frame(height: Theme.topBarHeight)
    }
}

/// 空状态文案（与 Android 主界面同一句，用户换手机不用重新认一遍）
public struct EmptyHint: View {
    let text: String
    public var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "note.text")
                .font(.system(size: 34))
                .foregroundStyle(.tertiary)
            Text(text)
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
