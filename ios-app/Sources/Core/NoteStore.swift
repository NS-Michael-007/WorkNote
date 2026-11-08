import Foundation

/// 本机存储。iOS 端数据量很小（自用几百条），直接用一个 JSON 文件，
/// 不做 Core Data / SQLite 迁移负担；写入用「先写临时文件再替换」，避免写一半断电把库写坏。
public final class NoteStore {

    private let fileURL: URL
    private let queue = DispatchQueue(label: "com.workspace.worknote.store")
    private var cache: [Note] = []

    public init(fileURL: URL) {
        self.fileURL = fileURL
        load()
    }

    public convenience init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let dir = base.appendingPathComponent("WorkNote", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        self.init(fileURL: dir.appendingPathComponent("notes.json"))
    }

    // MARK: - 读

    public func all() -> [Note] { queue.sync { cache } }

    public func active() -> [Note] { all().filter { $0.status.isActive } }

    public func trashed() -> [Note] { all().filter { $0.status == .deleted } }

    public func notes(onDateKey key: String) -> [Note] {
        all().filter { $0.dateKey == key && $0.status != .deleted }
            .sorted { lhs, rhs in
                if lhs.remindAt == 0 { return false }
                if rhs.remindAt == 0 { return true }
                return lhs.remindAt < rhs.remindAt
            }
    }

    public func find(id: UUID) -> Note? { all().first { $0.id == id } }

    // MARK: - 写

    public func save(_ note: Note) {
        queue.sync {
            if let idx = cache.firstIndex(where: { $0.id == note.id }) {
                cache[idx] = note
            } else {
                cache.append(note)
            }
            persist()
        }
    }

    public func delete(id: UUID) {
        queue.sync {
            guard let idx = cache.firstIndex(where: { $0.id == id }) else { return }
            cache[idx].status = .deleted
            persist()
        }
    }

    public func restore(id: UUID) {
        queue.sync {
            guard let idx = cache.firstIndex(where: { $0.id == id }) else { return }
            cache[idx].status = .pending
            persist()
        }
    }

    public func purge(id: UUID) {
        queue.sync {
            cache.removeAll { $0.id == id }
            persist()
        }
    }

    /// 导入备份用：整体替换，不是合并（与契约第四节一致）
    @discardableResult
    public func replaceAll(with notes: [Note]) -> Int {
        queue.sync {
            cache = notes
            persist()
            return notes.count
        }
    }

    // MARK: - 落盘

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { cache = []; return }
        guard let decoded = try? JSONDecoder().decode([PersistedNote].self, from: data) else {
            cache = []
            return
        }
        cache = decoded.map { $0.toNote() }
    }

    private func persist() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(cache.map { PersistedNote(from: $0) }) else { return }
        let tmp = fileURL.appendingPathExtension("tmp")
        do {
            try data.write(to: tmp, options: .atomic)
            if FileManager.default.fileExists(atPath: fileURL.path) {
                _ = try FileManager.default.replaceItemAt(fileURL, withItemAt: tmp)
            } else {
                try FileManager.default.moveItem(at: tmp, to: fileURL)
            }
        } catch {
            // 落盘失败不该让界面崩：内存里还有数据，下次写入会再试
        }
    }
}

/// 落盘用的中间结构：把 UUID 显式写进去，避免每次启动重新生成导致「记录对不上」
private struct PersistedNote: Codable {
    var id: UUID
    var title: String
    var remark: String
    var dateKey: String
    var remindAt: Int64
    var loopType: String
    var repeatEnabled: Bool
    var repeatMinutes: Int
    var status: String
    var createdAt: Int64
    var remindCount: Int
    var actions: [PersistedAction]

    init(from note: Note) {
        id = note.id
        title = note.title
        remark = note.remark
        dateKey = note.dateKey
        remindAt = note.remindAt
        loopType = note.loopType.rawValue
        repeatEnabled = note.repeatEnabled
        repeatMinutes = note.repeatMinutes
        status = note.status.rawValue
        createdAt = note.createdAt
        remindCount = note.remindCount
        actions = note.actions.map { PersistedAction(from: $0) }
    }

    func toNote() -> Note {
        Note(
            id: id,
            title: title,
            remark: remark,
            dateKey: dateKey,
            remindAt: remindAt,
            loopType: LoopType(rawValue: loopType) ?? .none,
            repeatEnabled: repeatEnabled,
            repeatMinutes: repeatMinutes,
            status: NoteStatus(rawValue: status) ?? .pending,
            createdAt: createdAt,
            remindCount: remindCount,
            actions: actions.map { $0.toAction() }
        )
    }
}

private struct PersistedAction: Codable {
    var text: String
    var type: String

    init(from action: NoteAction) {
        text = action.text
        type = action.type.rawValue
    }

    func toAction() -> NoteAction {
        NoteAction(text: text, type: ActionType(rawValue: type) ?? .done)
    }
}
