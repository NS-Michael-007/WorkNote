import Foundation

/// 时间相关的唯一入口。全部按**本地日历**算，不用 UTC，否则跨时区会错一天。
public enum TimeKey {

    public static var calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.locale = Locale(identifier: "zh_Hans_CN")
        cal.timeZone = .current
        return cal
    }()

    public static func nowMillis() -> Int64 {
        Int64(Date().timeIntervalSince1970 * 1000)
    }

    /// 毫秒时间戳 -> Date；0 视为「没有时间」
    public static func date(fromMillis millis: Int64) -> Date? {
        guard millis > 0 else { return nil }
        return Date(timeIntervalSince1970: Double(millis) / 1000.0)
    }

    public static func millis(from date: Date) -> Int64 {
        Int64(date.timeIntervalSince1970 * 1000)
    }

    /// 本地日历日 key，形如 2026-11-09
    public static func key(for date: Date) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 1970, c.month ?? 1, c.day ?? 1)
    }

    public static func todayKey() -> String { key(for: Date()) }

    /// 解析 yyyy-MM-dd；非法或不存在（例如 02-30）返回 nil
    public static func date(fromKey key: String) -> Date? {
        let parts = key.split(separator: "-")
        guard parts.count == 3,
              let y = Int(parts[0]), let m = Int(parts[1]), let d = Int(parts[2]) else { return nil }
        guard m >= 1, m <= 12, d >= 1, d <= 31 else { return nil }
        var comps = DateComponents()
        comps.year = y
        comps.month = m
        comps.day = d
        comps.hour = 12
        guard let date = calendar.date(from: comps) else { return nil }
        // Calendar 会把 2 月 30 日顺延到 3 月，这里用回读校验，拒绝不存在的日期
        let back = calendar.dateComponents([.year, .month, .day], from: date)
        guard back.year == y, back.month == m, back.day == d else { return nil }
        return date
    }

    /// 月份第一天 / 天数
    public static func daysInMonth(year: Int, month: Int) -> Int {
        var comps = DateComponents()
        comps.year = year
        comps.month = month
        comps.day = 1
        guard let first = calendar.date(from: comps),
              let range = calendar.range(of: .day, in: .month, for: first) else { return 30 }
        return range.count
    }

    /// 一天里的第 N 天（1 起），用于日程页纵列
    public static func dayDate(year: Int, month: Int, day: Int) -> Date? {
        var comps = DateComponents()
        comps.year = year
        comps.month = month
        comps.day = day
        comps.hour = 12
        return calendar.date(from: comps)
    }

    /// 把「同一个月里的第 31 天」夹到该月最后一天（每月循环用）
    public static func clampDay(_ day: Int, year: Int, month: Int) -> Int {
        min(day, daysInMonth(year: year, month: month))
    }

    /// 时分显示 10:30
    public static func hhmm(_ date: Date) -> String {
        let c = calendar.dateComponents([.hour, .minute], from: date)
        return String(format: "%02d:%02d", c.hour ?? 0, c.minute ?? 0)
    }

    /// 相对日期文案：今天 / 明天 / 昨天 / 带年份的具体日期（2026年11月9日 周日）
    public static func friendlyDay(_ date: Date, now: Date = Date()) -> String {
        let today = calendar.startOfDay(for: now)
        let target = calendar.startOfDay(for: date)
        let delta = calendar.dateComponents([.day], from: today, to: target).day ?? 0
        if delta == 0 { return "今天" }
        if delta == 1 { return "明天" }
        if delta == -1 { return "昨天" }
        let c = calendar.dateComponents([.year, .month, .day, .weekday], from: date)
        let weekdayNames = ["周日", "周一", "周二", "周三", "周四", "周五", "周六"]
        let idx = (c.weekday ?? 1) - 1
        let name = weekdayNames[max(0, min(6, idx))]
        return "\(c.year ?? 0)年\(c.month ?? 0)月\(c.day ?? 0)日 \(name)"
    }

    /// 某天的星期名，用于日程页
    public static func weekdayName(of date: Date) -> String {
        let c = calendar.dateComponents([.weekday], from: date)
        let names = ["周日", "周一", "周二", "周三", "周四", "周五", "周六"]
        return names[max(0, min(6, (c.weekday ?? 1) - 1))]
    }
}
