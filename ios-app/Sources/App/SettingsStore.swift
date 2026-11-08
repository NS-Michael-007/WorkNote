import Foundation
import SwiftUI

/// 设置项。键名与 Android 的 `worknote_settings.xml` 对齐，方便以后写「设置迁移」时对照。
public final class SettingsStore: ObservableObject {

    public enum DarkMode: Int, CaseIterable, Identifiable {
        case system = 0, light = 1, dark = 2
        public var id: Int { rawValue }
        public var titleZh: String {
            switch self {
            case .system: return "跟随系统"
            case .light: return "浅色"
            case .dark: return "深色"
            }
        }
    }

    public enum Language: String, CaseIterable, Identifiable {
        case system, zh, zhHant = "zh-Hant", en
        public var id: String { rawValue }
        public var titleZh: String {
            switch self {
            case .system: return "跟随系统"
            case .zh: return "简体中文"
            case .zhHant: return "繁體中文"
            case .en: return "English"
            }
        }
        /// 写进 AppleLanguages 的代码，跟随系统时返回 nil（不写，交回系统决定）
        public var appleLanguageCode: String? {
            switch self {
            case .system: return nil
            case .zh: return "zh-Hans"
            case .zhHant: return "zh-Hant"
            case .en: return "en"
            }
        }
    }

    public enum Keys {
        public static let darkMode = "dark_mode"
        public static let fontLevel = "font_level"
        public static let language = "language"
        public static let notifySound = "notify_sound"
        public static let notifyBadge = "notify_badge"
        public static let delayMinutes = "delay_minutes"
        public static let repeatMinutes = "repeat_minutes"
        public static let backgroundPath = "background_path"
    }

    private let defaults: UserDefaults

    @Published public var darkMode: DarkMode {
        didSet { defaults.set(darkMode.rawValue, forKey: Keys.darkMode) }
    }
    /// 1~10 档，默认 4 档 = 1.00 倍
    @Published public var fontLevel: Int {
        didSet { defaults.set(fontLevel, forKey: Keys.fontLevel) }
    }
    @Published public var language: Language {
        didSet { defaults.set(language.rawValue, forKey: Keys.language) }
    }
    @Published public var notifySound: Bool {
        didSet { defaults.set(notifySound, forKey: Keys.notifySound) }
    }
    @Published public var notifyBadge: Bool {
        didSet { defaults.set(notifyBadge, forKey: Keys.notifyBadge) }
    }
    /// 默认延后多少分钟
    @Published public var delayMinutes: Int {
        didSet { defaults.set(delayMinutes, forKey: Keys.delayMinutes) }
    }
    /// 没处理时的重弹间隔
    @Published public var repeatMinutes: Int {
        didSet { defaults.set(repeatMinutes, forKey: Keys.repeatMinutes) }
    }
    /// 自定义背景图文件名（存在 App 沙盒里），空串表示默认纯色
    @Published public var backgroundPath: String {
        didSet { defaults.set(backgroundPath, forKey: Keys.backgroundPath) }
    }

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let rawDark = defaults.object(forKey: Keys.darkMode) as? Int ?? 0
        darkMode = DarkMode(rawValue: rawDark) ?? .system
        let rawFont = defaults.object(forKey: Keys.fontLevel) as? Int ?? 4
        fontLevel = min(10, max(1, rawFont))
        language = Language(rawValue: defaults.string(forKey: Keys.language) ?? "system") ?? .system
        notifySound = defaults.object(forKey: Keys.notifySound) as? Bool ?? true
        notifyBadge = defaults.object(forKey: Keys.notifyBadge) as? Bool ?? true
        delayMinutes = defaults.object(forKey: Keys.delayMinutes) as? Int ?? 30
        repeatMinutes = defaults.object(forKey: Keys.repeatMinutes) as? Int ?? 15
        backgroundPath = defaults.string(forKey: Keys.backgroundPath) ?? ""
    }

    /// 字号倍数：与 Android 的 fontScale = 0.80 + level * 0.05 完全一致
    public var fontScale: Double {
        0.80 + Double(fontLevel) * 0.05
    }

    public var preferredColorScheme: ColorScheme? {
        switch darkMode {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    /// 语言落地点：写入 AppleLanguages，App 下次冷启动时由系统接管 .lproj 的选表。
    /// iOS 不允许运行期换 Bundle 的主语言，所以这里只落盘；界面需要提示「重启生效」。
    /// 返回 true 表示这次真的改了语言表，需要提示用户重启。
    @discardableResult
    public func applyLanguageToSystem() -> Bool {
        let key = "AppleLanguages"
        let wanted: [String]?
        if let code = language.appleLanguageCode {
            wanted = [code]
        } else {
            wanted = nil
        }
        let current = defaults.stringArray(forKey: key)
        if let wanted = wanted {
            if current == wanted { return false }
            defaults.set(wanted, forKey: key)
            return true
        }
        if current == nil { return false }
        defaults.removeObject(forKey: key)
        return true
    }
}
