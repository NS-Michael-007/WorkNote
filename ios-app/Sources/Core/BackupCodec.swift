import Foundation

/// 备份文件的读写。严格按 `docs/三端共享契约（数据模型与备份格式）.md` 实现，
/// 导入规则必须和 Android 的 `BackupManager` 完全一致，否则换机会丢数据。
public enum BackupError: LocalizedError, Equatable {
    case notJSON(String)
    case notOurFile
    case unsupportedVersion(Int)
    case emptyNotes

    public var errorDescription: String? {
        switch self {
        case .notJSON(let detail): return "不是合法 JSON：\(detail)"
        case .notOurFile: return "不是「工作便签提醒」的备份文件"
        case .unsupportedVersion(let v): return "备份版本 \(v) 这个版本还不支持，请升级 App"
        case .emptyNotes: return "备份里没有便签"
        }
    }
}

/// 校验结果：errors 非空就不该导入；warnings 只提示，不阻止
public struct BackupReport: Equatable, Sendable {
    public var errors: [String] = []
    public var warnings: [String] = []
    public var isValid: Bool { errors.isEmpty }

    public init(errors: [String] = [], warnings: [String] = []) {
        self.errors = errors
        self.warnings = warnings
    }
}

public enum BackupCodec {

    public static let appIdentifiers: Set<String> = ["工作便签提醒", "WorkNote"]
    public static let currentVersion = 1
    public static let maxTitleLength = 60
    public static let maxRemarkLength = 500
    public static let maxActionTextLength = 12
    public static let maxActions = 4
    /// 时间戳合理区间：2000-01-01 ~ 2100-01-01（毫秒）
    public static let minTimestamp: Int64 = 946_684_800_000
    public static let maxTimestamp: Int64 = 4_102_444_800_000

    // MARK: - 导出

    public static func encode(notes: [Note], exportedAt: Int64 = TimeKey.nowMillis()) -> Data {
        let root: [String: Any] = [
            "app": "工作便签提醒",
            "version": currentVersion,
            "exportedAt": exportedAt,
            "notes": notes.map { jsonObject(for: $0) }
        ]
        // .sortedKeys 只为让不同端产出的文件可 diff；.prettyPrinted 方便人肉排查
        let options: JSONSerialization.WritingOptions = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return (try? JSONSerialization.data(withJSONObject: root, options: options)) ?? Data("{}".utf8)
    }

    private static func jsonObject(for note: Note) -> [String: Any] {
        var obj: [String: Any] = [
            "title": note.title,
            "remark": note.remark,
            "dateKey": note.dateKey,
            "remindAt": note.remindAt,
            "loopType": note.loopType.rawValue,
            "repeatEnabled": note.repeatEnabled,
            "repeatMinutes": note.repeatMinutes,
            "status": note.status.rawValue,
            "createdAt": note.createdAt,
            "remindCount": note.remindCount
        ]
        obj["actions"] = note.actions.map { ["text": $0.text, "type": $0.type.rawValue] }
        return obj
    }

    // MARK: - 导入

    public static func decode(data: Data) throws -> (notes: [Note], report: BackupReport) {
        guard let object = try? JSONSerialization.jsonObject(with: data) else {
            throw BackupError.notJSON("解析失败")
        }
        guard let root = object as? [String: Any] else {
            throw BackupError.notJSON("根节点不是对象")
        }
        let app = root["app"] as? String ?? ""
        guard appIdentifiers.contains(app) else { throw BackupError.notOurFile }

        let version = intValue(root["version"]) ?? currentVersion
        guard version == currentVersion else { throw BackupError.unsupportedVersion(version) }

        guard let rawNotes = root["notes"] as? [[String: Any]] else {
            throw BackupError.notJSON("notes 不是数组")
        }
        guard !rawNotes.isEmpty else { throw BackupError.emptyNotes }

        var notes: [Note] = []
        var report = BackupReport()
        for (index, raw) in rawNotes.enumerated() {
            let parsed = note(from: raw, index: index, report: &report)
            notes.append(parsed)
        }
        return (notes, report)
    }

    /// 只校验不导入，给「选文件后先给用户看问题」用
    public static func validate(data: Data) -> BackupReport {
        do {
            let (_, report) = try decode(data: data)
            return report
        } catch {
            return BackupReport(errors: [error.localizedDescription])
        }
    }

    private static func note(from raw: [String: Any], index: Int, report: inout BackupReport) -> Note {
        let where_ = "notes[\(index)]"

        var title = trimmed(raw["title"] as? String)
        if raw["title"] == nil {
            // 契约里 title 是必填。缺失属于「文件不合格」，按错误拦下（Android 端是宽容补默认值，
            // 这里更严：宁可让用户重导一次，也不要悄悄建出一条「未命名便签」）。
            report.errors.append("\(where_): 缺少必填字段 title")
            title = "未命名便签"
        } else if title.isEmpty {
            report.warnings.append("\(where_): 标题为空，已补成「未命名便签」")
            title = "未命名便签"
        }
        if title.count > maxTitleLength {
            report.errors.append("\(where_): 标题超过 \(maxTitleLength) 字（\(title.count)）")
        }

        let remark = raw["remark"] as? String ?? ""
        if remark.count > maxRemarkLength {
            report.errors.append("\(where_): 备注超过 \(maxRemarkLength) 字（\(remark.count)）")
        }

        var dateKey = raw["dateKey"] as? String ?? TimeKey.todayKey()
        if raw["dateKey"] == nil {
            report.errors.append("\(where_): 缺少必填字段 dateKey")
        } else if TimeKey.date(fromKey: dateKey) == nil {
            report.errors.append("\(where_): dateKey 不是真实日期（\(dateKey)）")
            dateKey = TimeKey.todayKey()
        }

        let remindAt = int64Value(raw["remindAt"]) ?? 0
        if remindAt != 0 && (remindAt < minTimestamp || remindAt > maxTimestamp) {
            report.errors.append("\(where_): remindAt 超出合理范围（\(remindAt)）")
        }

        let loop = LoopType(rawValue: raw["loopType"] as? String ?? "") ?? .none
        if let rawLoop = raw["loopType"] as? String, LoopType(rawValue: rawLoop) == nil {
            report.errors.append("\(where_): loopType 不认识（\(rawLoop)）")
        }

        let statusRaw = raw["status"] as? String ?? NoteStatus.pending.rawValue
        var status = NoteStatus(rawValue: statusRaw) ?? .pending
        if NoteStatus(rawValue: statusRaw) == nil {
            report.errors.append("\(where_): status 不认识（\(statusRaw)）")
        }

        // —— 契约第四节的导入规则 ——
        // DELETED 保持进回收站；其余（含 READY / POSTPONED / DONE / ARCHIVED）一律回落 PENDING。
        // 理由：READY 与 POSTPONED 是「系统正在调度」的中间态，换了设备调度表已不存在，
        // 硬保留会让提醒永久不响；DONE / ARCHIVED 保留会让用户以为任务丢了。
        if status == .deleted {
            status = .deleted
        } else {
            status = .pending
        }

        var repeatMinutes = intValue(raw["repeatMinutes"]) ?? 15
        if repeatMinutes < 1 || repeatMinutes > 1440 {
            report.errors.append("\(where_): repeatMinutes 必须在 1~1440（\(repeatMinutes)）")
            repeatMinutes = min(1440, max(1, repeatMinutes))
        }

        let repeatEnabled = (raw["repeatEnabled"] as? Bool) ?? false

        var createdAt = int64Value(raw["createdAt"]) ?? TimeKey.nowMillis()
        if createdAt < minTimestamp || createdAt > maxTimestamp {
            report.warnings.append("\(where_): createdAt 不在合理区间，已按当前时间重写")
            createdAt = TimeKey.nowMillis()
        }

        var actions: [NoteAction] = []
        if let rawActions = raw["actions"] as? [[String: Any]] {
            if rawActions.count > maxActions {
                report.errors.append("\(where_): 按钮超过 \(maxActions) 个（\(rawActions.count)）")
            }
            for (j, rawAction) in rawActions.enumerated() {
                let actWhere = "\(where_).actions[\(j)]"
                let text = trimmed(rawAction["text"] as? String)
                guard !text.isEmpty else {
                    report.errors.append("\(actWhere): 按钮文字为空")
                    continue
                }
                if text.count > maxActionTextLength {
                    report.errors.append("\(actWhere): 按钮文字超过 \(maxActionTextLength) 字（\(text.count)）")
                }
                let type = ActionType(rawValue: rawAction["type"] as? String ?? "") ?? .done
                if let rawType = rawAction["type"] as? String, ActionType(rawValue: rawType) == nil {
                    report.errors.append("\(actWhere): type 不认识（\(rawType)）")
                }
                actions.append(NoteAction(text: text, type: type))
            }
        }

        // remindCount 一律归零；id 由本机重新生成（UUID，不写进文件）
        return Note(
            title: title,
            remark: remark,
            dateKey: dateKey,
            remindAt: remindAt,
            loopType: loop,
            repeatEnabled: repeatEnabled,
            repeatMinutes: repeatMinutes,
            status: status,
            createdAt: createdAt,
            remindCount: 0,
            actions: actions
        )
    }

    // MARK: - 小工具

    private static func trimmed(_ value: String?) -> String {
        (value ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func intValue(_ any: Any?) -> Int? {
        if let v = any as? Int { return v }
        if let v = any as? NSNumber { return v.intValue }
        if let v = any as? String { return Int(v) }
        return nil
    }

    private static func int64Value(_ any: Any?) -> Int64? {
        if let v = any as? Int64 { return v }
        if let v = any as? NSNumber { return v.int64Value }
        if let v = any as? String { return Int64(v) }
        return nil
    }

    /// 给界面用的默认文件名：WorkNote_yyyyMMdd_HHmm.taskbak
    public static func suggestedFileName(now: Date = Date()) -> String {
        let cal = TimeKey.calendar
        let c = cal.dateComponents([.year, .month, .day, .hour, .minute], from: now)
        return String(format: "WorkNote_%04d%02d%02d_%02d%02d.taskbak",
                      c.year ?? 1970, c.month ?? 1, c.day ?? 1, c.hour ?? 0, c.minute ?? 0)
    }
}
