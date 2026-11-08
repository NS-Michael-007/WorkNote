import Foundation

/// 提醒排期计算。纯函数、不碰系统 API，方便单测——iOS 端的闹钟一旦算错，
/// 表现是「提醒不响」，比 UI 错了严重得多，所以这块必须能测。
public enum ReminderPlanner {

    /// 下一次该响的时刻。
    /// - Parameter reference: 从这个时刻往后找（通常传 Date()）
    /// - Returns: 没有下一次则返回 nil（不设定时、已处理、或一次性且已过去）
    public static func nextFire(for note: Note, after reference: Date) -> Date? {
        guard note.status.isActive, note.remindAt > 0, let base = TimeKey.date(fromMillis: note.remindAt) else {
            return nil
        }
        guard base > reference else {
            // 一次性提醒已经过去：只要没处理，仍然要让界面提示「逾期」，但排期不再往后找
            guard note.loopType != .none else { return nil }
            return advance(note: note, from: base, after: reference)
        }
        return base
    }

    /// 循环推进：从 base 往后推到第一个严格晚于 reference 的时刻
    public static func advance(note: Note, from base: Date, after reference: Date) -> Date? {
        let cal = TimeKey.calendar
        var cursor = base
        // 一天的步长足够覆盖所有循环类型；上限 4000 次防御死循环
        for _ in 0..<4000 {
            switch note.loopType {
            case .none:
                return nil
            case .daily:
                cursor = cal.date(byAdding: .day, value: 1, to: cursor) ?? cursor
            case .weekly:
                cursor = cal.date(byAdding: .day, value: 7, to: cursor) ?? cursor
            case .monthly:
                cursor = nextMonthSameTime(from: cursor) ?? cursor
            }
            if cursor > reference { return cursor }
        }
        return nil
    }

    /// 月份 +1，日号保持不变；该月没有这个日号时夹到最后一天（2 月 31 日 -> 2 月 28/29 日）
    public static func nextMonthSameTime(from date: Date) -> Date? {
        let cal = TimeKey.calendar
        let c = cal.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        guard let y = c.year, let m = c.month, let d = c.day else { return nil }
        let nextYear = m == 12 ? y + 1 : y
        let nextMonth = m == 12 ? 1 : m + 1
        let clampedDay = TimeKey.clampDay(d, year: nextYear, month: nextMonth)
        var comps = DateComponents()
        comps.year = nextYear
        comps.month = nextMonth
        comps.day = clampedDay
        comps.hour = c.hour
        comps.minute = c.minute
        return cal.date(from: comps)
    }

    /// 没处理时的「再催」时刻：以最后一次响铃为基准加间隔
    public static func nextRepeat(after lastFire: Date, minutes: Int) -> Date? {
        guard minutes > 0 else { return nil }
        return TimeKey.calendar.date(byAdding: .minute, value: minutes, to: lastFire)
    }

    /// 一条便签未来 window 天内所有会响的时刻（给「今天要响几次」这类汇总用）
    public static func fires(for note: Note, within days: Int, from start: Date = Date()) -> [Date] {
        guard note.status.isActive, let end = TimeKey.calendar.date(byAdding: .day, value: days, to: start) else {
            return []
        }
        var result: [Date] = []
        var cursor: Date? = nextFire(for: note, after: start)
        while let fire = cursor, fire <= end, result.count < 1000 {
            result.append(fire)
            if note.loopType == .none { break }
            cursor = advance(note: note, from: fire, after: fire)
        }
        return result
    }

    /// 逾期待办：提醒时刻已经过去但还没处理
    public static func isOverdue(_ note: Note, now: Date = Date()) -> Bool {
        guard note.status.isActive, note.remindAt > 0, let base = TimeKey.date(fromMillis: note.remindAt) else {
            return false
        }
        return base < now
    }
}
