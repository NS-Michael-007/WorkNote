import XCTest

/// 排期计算的测试。iOS 端算错的后果是「到点不响」，比界面错更难发现，所以这些用例必须先绿。
final class ReminderPlannerTests: XCTestCase {

    private func makeDate(_ y: Int, _ m: Int, _ d: Int, _ hh: Int, _ mm: Int) -> Date {
        var comps = DateComponents()
        comps.year = y; comps.month = m; comps.day = d; comps.hour = hh; comps.minute = mm
        return TimeKey.calendar.date(from: comps)!
    }

    private func makeNote(remindAt: Date, loop: LoopType, status: NoteStatus = .pending,
                          repeatEnabled: Bool = false, repeatMinutes: Int = 15) -> Note {
        Note(title: "测试", dateKey: TimeKey.key(for: remindAt),
             remindAt: TimeKey.millis(from: remindAt), loopType: loop,
             repeatEnabled: repeatEnabled, repeatMinutes: repeatMinutes, status: status,
             createdAt: TimeKey.millis(from: remindAt))
    }

    func testOnceInFutureReturnsSameTime() {
        let fire = makeDate(2026, 11, 9, 10, 30)
        let note = makeNote(remindAt: fire, loop: .none)
        let next = ReminderPlanner.nextFire(for: note, after: makeDate(2026, 11, 8, 12, 0))
        XCTAssertEqual(next, fire)
    }

    func testOnceInPastReturnsNil() {
        let fire = makeDate(2026, 11, 8, 10, 30)
        let note = makeNote(remindAt: fire, loop: .none)
        XCTAssertNil(ReminderPlanner.nextFire(for: note, after: makeDate(2026, 11, 8, 12, 0)))
    }

    func testDailySkipsToNextDay() {
        let fire = makeDate(2026, 11, 8, 9, 0)
        let note = makeNote(remindAt: fire, loop: .daily)
        let next = ReminderPlanner.nextFire(for: note, after: makeDate(2026, 11, 8, 10, 0))
        XCTAssertEqual(next, makeDate(2026, 11, 9, 9, 0))
    }

    func testWeeklyJumpsSevenDays() {
        let fire = makeDate(2026, 11, 9, 10, 0)
        let note = makeNote(remindAt: fire, loop: .weekly)
        let next = ReminderPlanner.nextFire(for: note, after: makeDate(2026, 11, 16, 11, 0))
        XCTAssertEqual(next, makeDate(2026, 11, 23, 10, 0))
    }

    /// 每月 31 号：2 月没有 31 号，必须夹到 2 月最后一天，而不是跳到 3 月
    func testMonthlyClampsToMonthEnd() {
        let fire = makeDate(2026, 1, 31, 9, 0)
        let note = makeNote(remindAt: fire, loop: .monthly)
        let next = ReminderPlanner.nextFire(for: note, after: makeDate(2026, 1, 31, 10, 0))
        XCTAssertEqual(next, makeDate(2026, 2, 28, 9, 0), "2026 年不是闰年，2 月只有 28 天")

        let leap = makeDate(2028, 1, 31, 9, 0)
        let leapNote = makeNote(remindAt: leap, loop: .monthly)
        XCTAssertEqual(ReminderPlanner.nextFire(for: leapNote, after: makeDate(2028, 1, 31, 10, 0)),
                       makeDate(2028, 2, 29, 9, 0), "2028 是闰年，应该夹到 2 月 29 日")
    }

    func testDoneOrArchivedHasNoFire() {
        let fire = makeDate(2026, 11, 9, 10, 0)
        XCTAssertNil(ReminderPlanner.nextFire(for: makeNote(remindAt: fire, loop: .daily, status: .done), after: makeDate(2026, 11, 8, 10, 0)))
        XCTAssertNil(ReminderPlanner.nextFire(for: makeNote(remindAt: fire, loop: .daily, status: .archived), after: makeDate(2026, 11, 8, 10, 0)))
        XCTAssertNotNil(ReminderPlanner.nextFire(for: makeNote(remindAt: fire, loop: .daily, status: .postponed), after: makeDate(2026, 11, 8, 10, 0)))
    }

    func testNoRemindAtReturnsNil() {
        var note = makeNote(remindAt: makeDate(2026, 11, 9, 10, 0), loop: .daily)
        note.remindAt = 0
        XCTAssertNil(ReminderPlanner.nextFire(for: note, after: Date()))
    }

    func testRepeatInterval() {
        let last = makeDate(2026, 11, 9, 10, 0)
        XCTAssertEqual(ReminderPlanner.nextRepeat(after: last, minutes: 15), makeDate(2026, 11, 9, 10, 15))
        XCTAssertNil(ReminderPlanner.nextRepeat(after: last, minutes: 0))
    }

    func testFiresWithinWindow() {
        let fire = makeDate(2026, 11, 9, 9, 0)
        let note = makeNote(remindAt: fire, loop: .daily)
        let fires = ReminderPlanner.fires(for: note, within: 3, from: makeDate(2026, 11, 8, 12, 0))
        XCTAssertEqual(fires.count, 3, "3 天窗口内应该排 3 次")
    }

    func testOverdueDetection() {
        let note = makeNote(remindAt: makeDate(2026, 11, 8, 9, 0), loop: .none)
        XCTAssertTrue(ReminderPlanner.isOverdue(note, now: makeDate(2026, 11, 8, 12, 0)))
        XCTAssertFalse(ReminderPlanner.isOverdue(note, now: makeDate(2026, 11, 8, 8, 0)))
    }
}

/// 日期 key 的边界：不存在的日期必须判定为非法，否则一条脏数据会让日程页整天消失
final class TimeKeyTests: XCTestCase {

    func testImpossibleDateRejected() {
        XCTAssertNil(TimeKey.date(fromKey: "2026-02-30"))
        XCTAssertNil(TimeKey.date(fromKey: "2026-13-01"))
        XCTAssertNil(TimeKey.date(fromKey: "2026-00-10"))
        XCTAssertNil(TimeKey.date(fromKey: "不是日期"))
        XCTAssertNotNil(TimeKey.date(fromKey: "2026-02-28"))
        XCTAssertNotNil(TimeKey.date(fromKey: "2028-02-29"), "2028 是闰年")
        XCTAssertNil(TimeKey.date(fromKey: "2026-02-29"), "2026 不是闰年")
    }

    func testKeyRoundTrip() {
        let date = TimeKey.date(fromKey: "2026-11-09")!
        XCTAssertEqual(TimeKey.key(for: date), "2026-11-09")
    }

    func testDaysInMonth() {
        XCTAssertEqual(TimeKey.daysInMonth(year: 2026, month: 2), 28)
        XCTAssertEqual(TimeKey.daysInMonth(year: 2028, month: 2), 29)
        XCTAssertEqual(TimeKey.daysInMonth(year: 2026, month: 4), 30)
        XCTAssertEqual(TimeKey.daysInMonth(year: 2026, month: 12), 31)
    }

    func testClampDay() {
        XCTAssertEqual(TimeKey.clampDay(31, year: 2026, month: 2), 28)
        XCTAssertEqual(TimeKey.clampDay(31, year: 2026, month: 4), 30)
        XCTAssertEqual(TimeKey.clampDay(15, year: 2026, month: 4), 15)
    }

    func testMillisRoundTrip() {
        let millis: Int64 = 1_794_600_000_000
        let date = TimeKey.date(fromMillis: millis)!
        XCTAssertEqual(TimeKey.millis(from: date), millis)
        XCTAssertNil(TimeKey.date(fromMillis: 0))
    }
}
