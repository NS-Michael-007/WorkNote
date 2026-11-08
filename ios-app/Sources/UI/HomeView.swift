import SwiftUI

/// 主界面：仿微信会话列表——一条便签一行，左边标题与备注，右边时间与状态。
struct HomeView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.colorScheme) private var scheme

    @State private var editingNote: Note?
    @State private var showRecycleBin = false
    @State private var showMenu = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                TopBar(title: "主界面") {
                    HStack(spacing: 18) {
                        Button {
                            editingNote = Note(title: "", dateKey: TimeKey.todayKey(), createdAt: TimeKey.nowMillis())
                        } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 19, weight: .medium))
                        }
                        Button { showMenu = true } label: {
                            Image(systemName: "ellipsis")
                                .font(.system(size: 19, weight: .medium))
                        }
                    }
                    .foregroundStyle(.primary)
                }

                if model.notes.filter({ $0.status != .deleted }).isEmpty {
                    EmptyHint(text: "还没有便签，点右上角 + 新建一条")
                } else {
                    List {
                        ForEach(model.notes.filter { $0.status != .deleted }) { note in
                            NoteRow(note: note)
                                .contentShape(Rectangle())
                                .onTapGesture { editingNote = note }
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button(role: .destructive) {
                                        model.delete(id: note.id)
                                    } label: { Label("删除", systemImage: "trash") }

                                    Button {
                                        model.setStatus(noteID: note.id, status: .done)
                                    } label: { Label("完成", systemImage: "checkmark") }
                                        .tint(Theme.accent)
                                }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .background(Theme.pageBackground(scheme))
            .sheet(item: $editingNote) { note in
                NoteEditorView(note: note)
            }
            .sheet(isPresented: $showRecycleBin) {
                RecycleBinView()
            }
            .confirmationDialog("更多", isPresented: $showMenu, titleVisibility: .visible) {
                Button("回收站（\(model.notes.filter { $0.status == .deleted }.count)）") { showRecycleBin = true }
                Button("取消", role: .cancel) {}
            }
        }
    }
}

/// 一行便签
struct NoteRow: View {
    let note: Note
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            RoundedRectangle(cornerRadius: 6)
                .fill(Theme.accent.opacity(note.status.isActive ? 0.9 : 0.25))
                .frame(width: 4, height: 34)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(note.title)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Theme.primaryText(scheme))
                        .lineLimit(1)
                    if note.loopType != .none {
                        Text(note.loopType.titleZh)
                            .font(.system(size: 10))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Theme.accent.opacity(0.12))
                            .foregroundStyle(Theme.accent)
                            .clipShape(RoundedRectangle(cornerRadius: 3))
                    }
                }
                if !note.remark.isEmpty {
                    Text(note.remark)
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.secondaryText(scheme))
                        .lineLimit(1)
                }
                HStack(spacing: 6) {
                    if let fire = TimeKey.date(fromMillis: note.remindAt) {
                        Text("\(TimeKey.friendlyDay(fire)) \(TimeKey.hhmm(fire))")
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.secondaryText(scheme))
                    } else {
                        Text("不设定时")
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.secondaryText(scheme))
                    }
                    if ReminderPlanner.isOverdue(note) {
                        Text("已逾期")
                            .font(.system(size: 11))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Theme.badge.opacity(0.12))
                            .foregroundStyle(Theme.badge)
                            .clipShape(RoundedRectangle(cornerRadius: 3))
                    }
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 6) {
                Text(note.status.titleZh)
                    .font(.system(size: 12))
                    .foregroundStyle(note.status == .deleted ? Theme.secondaryText(scheme) : Theme.accent)
                Text(note.dateKey.suffix(5))
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.secondaryText(scheme))
            }
        }
        .padding(.vertical, 8)
        .listRowBackground(Theme.cardBackground(scheme))
    }
}

/// 回收站
struct RecycleBinView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(model.notes.filter { $0.status == .deleted }) { note in
                    HStack {
                        Text(note.title).foregroundStyle(.primary)
                        Spacer()
                        Button("恢复") { model.restore(id: note.id) }
                            .buttonStyle(.borderless)
                            .tint(Theme.accent)
                        Button("彻底删除") { model.purge(id: note.id) }
                            .buttonStyle(.borderless)
                            .tint(Theme.badge)
                    }
                }
            }
            .navigationTitle("回收站")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("关闭") { dismiss() }
                }
            }
        }
    }
}
