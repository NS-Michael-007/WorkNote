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

/// 回收站。原来「点开一条自己恢复 / 彻底删除」的做法保持不变，
/// 另加右上角「多选」（逐条勾选后批量删）与「全部删除」（一次清空）。
struct RecycleBinView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme

    @State private var selecting = false
    @State private var selected = Set<UUID>()
    @State private var confirmSelected = false
    @State private var confirmAll = false
    @State private var hintText: String?

    private var trash: [Note] { model.notes.filter { $0.status == .deleted } }
    private var allSelected: Bool { !trash.isEmpty && selected.count == trash.count }

    var body: some View {
        NavigationStack {
            Group {
                if trash.isEmpty {
                    EmptyHint(text: "回收站是空的")
                } else {
                    List {
                        ForEach(trash) { note in
                            HStack(spacing: 10) {
                                if selecting {
                                    Image(systemName: selected.contains(note.id) ? "checkmark.circle.fill" : "circle")
                                        .font(.system(size: 20))
                                        .foregroundStyle(selected.contains(note.id) ? Theme.accent : Theme.secondaryText(scheme))
                                }
                                Text(note.title)
                                    .foregroundStyle(Theme.primaryText(scheme))
                                Spacer()
                                if !selecting {
                                    Button("恢复") { model.restore(id: note.id) }
                                        .buttonStyle(.borderless)
                                        .tint(Theme.accent)
                                    Button("彻底删除") { model.purge(id: note.id) }
                                        .buttonStyle(.borderless)
                                        .tint(Theme.badge)
                                }
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if selecting { toggle(note.id) }
                            }
                            .listRowBackground(Theme.cardBackground(scheme))
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .background(Theme.pageBackground(scheme))
            .navigationTitle("回收站")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if !trash.isEmpty {
                        Button(selecting ? "退出多选" : "多选") {
                            selecting.toggle()
                            if !selecting { selected.removeAll() }
                        }
                    }
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    if !trash.isEmpty && !selecting {
                        Button("全部删除") { confirmAll = true }
                            .tint(Theme.badge)
                    }
                    Button("关闭") { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if selecting && !trash.isEmpty {
                    HStack(spacing: 12) {
                        Button(allSelected ? "取消全选" : "全选") {
                            if allSelected { selected.removeAll() } else { selected = Set(trash.map { $0.id }) }
                        }
                        .buttonStyle(.borderless)
                        .tint(Theme.accent)
                        Text("已选 \(selected.count) 条")
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.secondaryText(scheme))
                        Spacer()
                        Button("删除所选（\(selected.count)）") {
                            if selected.isEmpty { hintText = "先勾选要删除的便签" } else { confirmSelected = true }
                        }
                        .buttonStyle(.borderless)
                        .tint(Theme.badge)
                    }
                    .padding(.horizontal, Theme.pageMargin)
                    .padding(.vertical, 8)
                    .background(.thinMaterial)
                }
            }
            .confirmationDialog("删除所选", isPresented: $confirmSelected, titleVisibility: .visible) {
                Button("删除所选（\(selected.count)）", role: .destructive) {
                    let ids = selected
                    selected.removeAll()
                    selecting = false
                    model.purge(ids: ids)
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("勾选的 \(selected.count) 条便签会被彻底删掉，只能靠以前的备份文件找回。")
            }
            .confirmationDialog("全部删除", isPresented: $confirmAll, titleVisibility: .visible) {
                Button("全部删除（\(trash.count)）", role: .destructive) {
                    model.purgeAllDeleted()
                    selected.removeAll()
                    selecting = false
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("回收站里的 \(trash.count) 条便签会全部彻底删掉，只能靠以前的备份文件找回。")
            }
            .alert("提示", isPresented: Binding(
                get: { hintText != nil },
                set: { if !$0 { hintText = nil } }
            )) {
                Button("好", role: .cancel) { hintText = nil }
            } message: {
                Text(hintText ?? "")
            }
        }
    }

    private func toggle(_ id: UUID) {
        if selected.contains(id) { selected.remove(id) } else { selected.insert(id) }
    }
}
