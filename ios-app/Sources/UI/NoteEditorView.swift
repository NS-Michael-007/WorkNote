import SwiftUI

/// 便签编辑页。字段与备份契约一一对应：标题 / 备注 / 归属日期 / 提醒时刻 / 循环 / 重弹 / 自定义按钮。
struct NoteEditorView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss

    @State private var title: String
    @State private var remark: String
    @State private var dateKey: String
    @State private var hasReminder: Bool
    @State private var remindDate: Date
    @State private var loopType: LoopType
    @State private var repeatEnabled: Bool
    @State private var repeatMinutes: Int
    @State private var actions: [NoteAction]
    @State private var errorText: String?

    private let original: Note

    init(note: Note) {
        original = note
        _title = State(initialValue: note.title)
        _remark = State(initialValue: note.remark)
        _dateKey = State(initialValue: note.dateKey)
        let has = note.remindAt > 0
        _hasReminder = State(initialValue: has)
        let date = TimeKey.date(fromMillis: note.remindAt) ?? Date()
        _remindDate = State(initialValue: date)
        _loopType = State(initialValue: note.loopType)
        _repeatEnabled = State(initialValue: note.repeatEnabled)
        _repeatMinutes = State(initialValue: note.repeatMinutes)
        _actions = State(initialValue: note.actions)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("内容") {
                    TextField("标题（必填）", text: $title)
                    TextField("备注", text: $remark, axis: .vertical)
                        .lineLimit(1...4)
                }

                Section("时间") {
                    // 归属日期：年 / 月 / 日 三段滚轮都能直接转，右边「今天」一键回到当天
                    HStack {
                        Text("归属日期")
                        Spacer()
                        Button("今天") { dateKey = TimeKey.key(for: Date()) }
                    }
                    DatePicker("归属日期", selection: Binding(
                        get: { TimeKey.date(fromKey: dateKey) ?? Date() },
                        set: { dateKey = TimeKey.key(for: $0) }
                    ), displayedComponents: .date)
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .frame(maxWidth: .infinity, alignment: .center)

                    Toggle("设定时提醒", isOn: $hasReminder)
                    if hasReminder {
                        // 提醒时刻同样按年月日 + 时分选，右边「今天」把日期挪到今天、时分不动
                        HStack {
                            Text("提醒时刻")
                            Spacer()
                            Button("改到今天") { moveReminderToToday() }
                        }
                        DatePicker("提醒时刻", selection: $remindDate, displayedComponents: [.date, .hourAndMinute])
                        .datePickerStyle(.wheel)
                        .labelsHidden()
                        .frame(maxWidth: .infinity, alignment: .center)
                        Picker("循环", selection: $loopType) {
                            ForEach(LoopType.allCases, id: \.self) { loop in
                                Text(loop.titleZh).tag(loop)
                            }
                        }
                        Toggle("没处理就再催", isOn: $repeatEnabled)
                        if repeatEnabled {
                            Stepper("每 \(repeatMinutes) 分钟催一次", value: $repeatMinutes, in: 5...240, step: 5)
                        }
                    }
                }

                Section {
                    ForEach(Array(actions.enumerated()), id: \.offset) { index, action in
                        HStack {
                            TextField("按钮文字", text: Binding(
                                get: { actions[index].text },
                                set: { actions[index].text = $0 }
                            ))
                            Picker("", selection: Binding(
                                get: { actions[index].type },
                                set: { actions[index].type = $0 }
                            )) {
                                ForEach(ActionType.allCases, id: \.self) { type in
                                    Text(type.titleZh).tag(type)
                                }
                            }
                            .labelsHidden()
                        }
                    }
                    .onDelete { actions.remove(atOffsets: $0) }

                    if actions.count < BackupCodec.maxActions {
                        Button("加一个按钮") {
                            actions.append(NoteAction(text: "已处理", type: .done))
                        }
                    }
                } header: {
                    Text("强提醒卡片按钮")
                } footer: {
                    Text("最多 4 个。不配就用默认的「完成」按钮。iOS 上这些按钮会显示在通知里。")
                }
            }
            .navigationTitle(original.title.isEmpty ? "新建便签" : "编辑便签")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .alert("保存失败", isPresented: Binding(
                get: { errorText != nil },
                set: { if !$0 { errorText = nil } }
            )) {
                Button("好", role: .cancel) { errorText = nil }
            } message: {
                Text(errorText ?? "")
            }
        }
    }

    /// 把提醒时刻的日期部分换成今天，时分保持不变
    private func moveReminderToToday() {
        let calendar = Calendar.current
        let time = calendar.dateComponents([.hour, .minute], from: remindDate)
        var target = calendar.dateComponents([.year, .month, .day], from: Date())
        target.hour = time.hour
        target.minute = time.minute
        if let merged = calendar.date(from: target) {
            remindDate = merged
        }
    }

    private func save() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return }
        if trimmedTitle.count > BackupCodec.maxTitleLength {
            errorText = "标题最多 \(BackupCodec.maxTitleLength) 字"
            return
        }
        for action in actions where action.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errorText = "按钮文字不能为空"
            return
        }

        var note = original
        note.title = trimmedTitle
        note.remark = remark
        note.dateKey = dateKey
        note.remindAt = hasReminder ? TimeKey.millis(from: remindDate) : 0
        note.loopType = hasReminder ? loopType : .none
        note.repeatEnabled = hasReminder ? repeatEnabled : false
        note.repeatMinutes = repeatMinutes
        note.actions = actions.filter { !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        if note.createdAt == 0 { note.createdAt = TimeKey.nowMillis() }
        if !note.status.isActive && note.status != .deleted { note.status = .pending }

        model.upsert(note)
        dismiss()
    }
}
