import Foundation
import SwiftUI

/// 导入时如果文件有硬错误，整份拒绝并把这些原因带回界面
struct BackupValidationError: LocalizedError {
    let errors: [String]
    var errorDescription: String? {
        "备份文件有 \(errors.count) 处问题，未导入：\n" + errors.prefix(5).joined(separator: "\n")
    }
}

/// 业务总闸。界面只跟它打交道；写库、排通知、导入导出都在这里收口。
@MainActor
final class AppModel: ObservableObject {

    @Published private(set) var notes: [Note] = []
    @Published var lastActionMessage: String?

    let store: NoteStore
    let settings: SettingsStore

    init(store: NoteStore = NoteStore(), settings: SettingsStore = SettingsStore()) {
        self.store = store
        self.settings = settings
        reload()
    }

    /// App 启动时调用一次：装通知代理、注册动作、按当前数据重排
    func bootstrap() {
        NotificationRouter.shared.install()
        ReminderCenter.registerCategories()
        NotificationRouter.shared.onAction = { [weak self] id, type in
            Task { @MainActor in self?.act(noteID: id, type: type) }
        }
        ReminderCenter.requestAuthorization()
        reschedule()
    }

    func reload() {
        notes = store.all()
    }

    // MARK: - 增删改

    func upsert(_ note: Note) {
        var note = note
        if note.createdAt == 0 { note.createdAt = TimeKey.nowMillis() }
        store.save(note)
        reload()
        reschedule()
    }

    func delete(id: UUID) {
        store.delete(id: id)
        reload()
        reschedule()
    }

    func restore(id: UUID) {
        store.restore(id: id)
        reload()
        reschedule()
    }

    func purge(id: UUID) {
        store.purge(id: id)
        reload()
        reschedule()
    }

    /// 通知按钮与卡片按钮的统一入口。语义与 Android 的 `NoteActions` 完全一致：
    /// - 完成 + 有循环 → 排下一次，状态回 PENDING，remindCount 清零，dateKey 跟着新时间走
    /// - 完成 + 无循环 → DONE，remindAt 归零
    /// - 延后 → POSTPONED，remindAt = 现在 + 延后分钟
    /// - 只关卡片 → 状态不动，只取消本次通知
    func act(noteID: UUID, type: ActionType) {
        guard var note = store.find(id: noteID) else { return }
        let now = TimeKey.nowMillis()

        switch type {
        case .delay:
            note.status = .postponed
            note.remindAt = now + Int64(settings.delayMinutes) * 60_000
        case .close:
            ReminderCenter.cancel(noteID: noteID)
        case .done:
            if note.loopType != .none {
                let base = note.remindAt > 0 ? note.remindAt : now
                let fromDate = TimeKey.date(fromMillis: base) ?? Date()
                if let next = ReminderPlanner.advance(note: note, from: fromDate, after: Date()) {
                    note.status = .pending
                    note.remindAt = TimeKey.millis(from: next)
                    note.dateKey = TimeKey.key(for: next)
                    note.remindCount = 0
                } else {
                    note.status = .done
                    note.remindAt = 0
                }
            } else {
                note.status = .done
                note.remindAt = 0
            }
        }

        store.save(note)
        reload()
        reschedule()
    }

    /// 手动改状态（列表左滑、详情页用）
    func setStatus(noteID: UUID, status: NoteStatus) {
        guard var note = store.find(id: noteID) else { return }
        note.status = status
        if status == .done && note.loopType == .none { note.remindAt = 0 }
        store.save(note)
        reload()
        reschedule()
    }

    func reschedule() {
        ReminderCenter.reschedule(notes)
    }

    // MARK: - 备份

    func exportData() -> Data {
        BackupCodec.encode(notes: store.all())
    }

    /// 返回导入条数；抛错时界面直接展示本地化文案。
    /// 有硬错误（缺必填、枚举不认识、超长等）一律整份拒绝——宁可让用户重导，也不要把半个坏文件写进库。
    func importData(_ data: Data) throws -> Int {
        let (imported, report) = try BackupCodec.decode(data: data)
        guard report.isValid else {
            throw BackupValidationError(errors: report.errors)
        }
        let count = store.replaceAll(with: imported)
        reload()
        reschedule()
        if let first = report.warnings.first {
            lastActionMessage = "已导入 \(count) 条；注意：\(first)"
        } else {
            lastActionMessage = "已导入 \(count) 条"
        }
        return count
    }

    // MARK: - 查询

    var activeNotes: [Note] { notes.filter { $0.status.isActive } }

    func notes(onDateKey key: String) -> [Note] {
        notes.filter { $0.dateKey == key && $0.status != .deleted }
    }

    var overdueCount: Int {
        notes.filter { ReminderPlanner.isOverdue($0) }.count
    }
}
