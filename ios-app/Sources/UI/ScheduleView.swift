import SwiftUI

/// 日程页：**纵列 1 号到月末**，不点前后箭头翻月，右上角一次性选年月（与 Android 版一致）。
struct ScheduleView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.colorScheme) private var scheme

    @State private var year: Int = TimeKey.calendar.component(.year, from: Date())
    @State private var month: Int = TimeKey.calendar.component(.month, from: Date())
    @State private var showPicker = false

    private var days: [Int] { Array(1...TimeKey.daysInMonth(year: year, month: month)) }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                TopBar(title: "日程") {
                    Button { showPicker = true } label: {
                        HStack(spacing: 4) {
                            Text("\(year)年\(month)月")
                                .font(.system(size: 15, weight: .medium))
                            Image(systemName: "chevron.down").font(.system(size: 11))
                        }
                        .foregroundStyle(.primary)
                    }
                }

                List {
                    ForEach(days, id: \.self) { day in
                        DayRow(year: year, month: month, day: day, notes: notesFor(day: day))
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
            .background(Theme.pageBackground(scheme))
            .sheet(isPresented: $showPicker) {
                MonthPickerSheet(year: $year, month: $month)
            }
        }
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
