import SwiftUI

/// 日程页：两种显示模式，看的是同一份数据。
/// 垂直模式——纵列 1 号到月末；日历模式——整月七列网格，点某天在下方列出当天便签。
/// 两种模式都支持左右滑动翻月：左滑下个月、右滑上个月。
/// 右上角一次性选年月（与 Android 版一致）。
struct ScheduleView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var settings: SettingsStore
    @Environment(\.colorScheme) private var scheme

    @State private var year: Int = TimeKey.calendar.component(.year, from: Date())
    @State private var month: Int = TimeKey.calendar.component(.month, from: Date())
    @State private var showPicker = false
    @State private var showModeDialog = false
    @State private var selectedDay: Int = TimeKey.calendar.component(.day, from: Date())

    private var days: [Int] { Array(1...TimeKey.daysInMonth(year: year, month: month)) }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                TopBar(title: "日程") {
                    HStack(spacing: 8) {
                        Button { showModeDialog = true } label: {
                            chip(settings.scheduleMode.shortZh + " ▾")
                        }
                        Button { showPicker = true } label: {
                            chip("\(year)年\(month)月 ▾")
                        }
                    }
                }

                if settings.scheduleMode == .list {
                    listMode
                } else {
                    calendarMode
                }
            }
            .background(Theme.pageBackground(scheme))
            .sheet(isPresented: $showPicker) {
                MonthPickerSheet(year: $year, month: $month)
            }
            .confirmationDialog("日程显示模式", isPresented: $showModeDialog, titleVisibility: .visible) {
                ForEach(SettingsStore.ScheduleMode.allCases) { mode in
                    Button(mode.titleZh) { settings.scheduleMode = mode }
                }
                Button("取消", role: .cancel) {}
            }
        }
    }

    // MARK: - 垂直模式

    private var listMode: some View {
        List {
            ForEach(days, id: \.self) { day in
                DayRow(year: year, month: month, day: day, notes: notesFor(day: day))
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .simultaneousGesture(monthSwipe)
    }

    // MARK: - 日历模式

    private var calendarMode: some View {
        ScrollView {
            VStack(spacing: 10) {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7), spacing: 6) {
                    ForEach(["周日", "周一", "周二", "周三", "周四", "周五", "周六"], id: \.self) { name in
                        Text(name)
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.secondaryText(scheme))
                    }
                    ForEach(0..<leadingBlanks, id: \.self) { _ in
                        Color.clear.frame(height: 46)
                    }
                    ForEach(days, id: \.self) { day in
                        dayCell(day)
                    }
                }
                .padding(.horizontal, 10)

                VStack(alignment: .leading, spacing: 8) {
                    Text(dayLabel)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.primaryText(scheme))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    selectedDayNotes
                }
                .padding(.horizontal, Theme.pageMargin)
                .padding(.bottom, 16)
            }
            .padding(.top, 8)
        }
        .simultaneousGesture(monthSwipe)
    }

    // MARK: - 左右滑动翻月

    /// 左滑下个月、右滑上个月；纵向为主的手势交给列表自己滚，不抢
    private var monthSwipe: some Gesture {
        DragGesture(minimumDistance: 30)
            .onEnded { value in
                let dx = value.translation.width
                let dy = value.translation.height
                guard abs(dx) > 50, abs(dx) > abs(dy) * 1.5 else { return }
                shiftMonth(dx < 0 ? 1 : -1)
            }
    }

    /// 翻到相邻月份：看的正是本月就选中今天，其它月份选 1 号；网格、表头与当天便签一起刷新
    private func shiftMonth(_ delta: Int) {
        var newYear = year
        var newMonth = month + delta
        if newMonth > 12 {
            newYear += 1
            newMonth = 1
        }
        if newMonth < 1 {
            newYear -= 1
            newMonth = 12
        }
        year = newYear
        month = newMonth
        let today = Date()
        let sameMonth = TimeKey.calendar.component(.year, from: today) == newYear
            && TimeKey.calendar.component(.month, from: today) == newMonth
        selectedDay = sameMonth ? TimeKey.calendar.component(.day, from: today) : 1
    }

    @ViewBuilder
    private var selectedDayNotes: some View {
        let notes = notesFor(day: selectedDay)
        if notes.isEmpty {
            Text("这天还没有便签")
                .font(.system(size: 12))
                .foregroundStyle(Theme.secondaryText(scheme))
        } else {
            ForEach(notes) { note in
                VStack(alignment: .leading, spacing: 3) {
                    Text(note.title)
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.primaryText(scheme))
                        .lineLimit(1)
                    HStack(spacing: 6) {
                        Text(note.status.titleZh)
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.accent)
                        if let fire = TimeKey.date(fromMillis: note.remindAt) {
                            Text("\(TimeKey.friendlyDay(fire)) \(TimeKey.hhmm(fire))")
                                .font(.system(size: 11))
                                .foregroundStyle(Theme.secondaryText(scheme))
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(Theme.cardBackground(scheme))
                .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius))
            }
        }
    }

    /// 1 号之前要空几格：周日打头，所以用 weekday - 1
    private var leadingBlanks: Int {
        guard let first = TimeKey.dayDate(year: year, month: month, day: 1) else { return 0 }
        return TimeKey.calendar.component(.weekday, from: first) - 1
    }

    private var dayLabel: String {
        guard let date = TimeKey.dayDate(year: year, month: month, day: selectedDay) else { return "" }
        let isToday = TimeKey.key(for: date) == TimeKey.key(for: Date())
        return "\(year)年\(month)月\(selectedDay)日 \(TimeKey.weekdayName(of: date))" + (isToday ? "（今天）" : "")
    }

    private func dayCell(_ day: Int) -> some View {
        let key = keyFor(day: day)
        let count = model.notes(onDateKey: key).count
        let selected = day == selectedDay
        let isToday = key == TimeKey.key(for: Date())
        return Button {
            selectedDay = day
        } label: {
            VStack(spacing: 1) {
                Text("\(day)")
                    .font(.system(size: 14, weight: selected ? .semibold : .regular))
                    .frame(maxWidth: .infinity, minHeight: 34)
                    .background(selected ? Theme.accent : Theme.cardBackground(scheme))
                    .foregroundStyle(selected ? Color.white : (isToday ? Theme.accent : Theme.primaryText(scheme)))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                Text(count > 0 ? "\(count)" : " ")
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.badge)
            }
        }
        .buttonStyle(.plain)
    }

    private func chip(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(.primary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Theme.cardBackground(scheme))
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func keyFor(day: Int) -> String {
        guard let date = TimeKey.dayDate(year: year, month: month, day: day) else { return "" }
        return TimeKey.key(for: date)
    }

    private func notesFor(day: Int) -> [Note] {
        guard let date = TimeKey.dayDate(year: year, month: month, day: day) else { return [] }
        return model.notes(onDateKey: TimeKey.key(for: date))
    }
}

/// 一行：日期 + 星期 + 条数（有便签时显示标题，没便签时保持一行高，纵向 1~月末连续不断）
struct DayRow: View {
    let year: Int
    let month: Int
    let day: Int
    let notes: [Note]

    @Environment(\.colorScheme) private var scheme

    private var date: Date? { TimeKey.dayDate(year: year, month: month, day: day) }

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(day)")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Theme.primaryText(scheme))
                if let date {
                    Text(TimeKey.weekdayName(of: date))
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.secondaryText(scheme))
                }
            }
            .frame(width: 40, alignment: .leading)

            if notes.isEmpty {
                Text("—")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.secondaryText(scheme))
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(notes) { note in
                        HStack(spacing: 6) {
                            Text(note.title)
                                .font(.system(size: 14))
                                .foregroundStyle(Theme.primaryText(scheme))
                                .lineLimit(1)
                            if let fire = TimeKey.date(fromMillis: note.remindAt) {
                                Text(TimeKey.hhmm(fire))
                                    .font(.system(size: 11))
                                    .foregroundStyle(Theme.secondaryText(scheme))
                            }
                        }
                    }
                }
            }

            Spacer()

            if !notes.isEmpty {
                Text("\(notes.count)")
                    .font(.system(size: 11))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Theme.accent.opacity(0.12))
                    .foregroundStyle(Theme.accent)
                    .clipShape(Capsule())
            }
        }
        .padding(.vertical, 6)
        .listRowBackground(Theme.cardBackground(scheme))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Theme.divider(scheme))
                .frame(height: 0.5)
        }
    }
}

/// 年月一次性选择：年份滚轮 + 12 个月格，选完直接关，不做「上个月 / 下个月」箭头
struct MonthPickerSheet: View {
    @Binding var year: Int
    @Binding var month: Int
    @Environment(\.dismiss) private var dismiss

    @State private var draftYear: Int
    @State private var draftMonth: Int

    init(year: Binding<Int>, month: Binding<Int>) {
        _year = year
        _month = month
        _draftYear = State(initialValue: year.wrappedValue)
        _draftMonth = State(initialValue: month.wrappedValue)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Picker("年份", selection: $draftYear) {
                    ForEach((draftYear - 3)...(draftYear + 3), id: \.self) { y in
                        Text("\(y)年").tag(y)
                    }
                }
                .pickerStyle(.wheel)
                .frame(height: 120)

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 10) {
                    ForEach(1...12, id: \.self) { m in
                        Text("\(m)月")
                            .font(.system(size: 15, weight: m == draftMonth ? .semibold : .regular))
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .background(m == draftMonth ? Theme.accent.opacity(0.15) : Color(.secondarySystemBackground))
                            .foregroundStyle(m == draftMonth ? Theme.accent : Color.primary)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .onTapGesture { draftMonth = m }
                    }
                }
                .padding(.horizontal, 16)

                Spacer()
            }
            .padding(.top, 8)
            .navigationTitle("选择年月")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("确定") {
                        year = draftYear
                        month = draftMonth
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}
