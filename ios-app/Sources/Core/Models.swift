import Foundation

/// 便签状态。与 Android 的 `Status`、备份文件里的字符串一一对应，改名会破坏跨端兼容。
public enum NoteStatus: String, Codable, CaseIterable, Sendable {
    case pending = "PENDING"
    case ready = "READY"
    case done = "DONE"
    case postponed = "POSTPONED"
    case archived = "ARCHIVED"
    case deleted = "DELETED"

    /// 只有这三种会弹强提醒
    public var isActive: Bool {
        switch self {
        case .pending, .ready, .postponed: return true
        case .done, .archived, .deleted: return false
        }
    }

    public var titleZh: String {
        switch self {
        case .pending: return "待"
        case .ready: return "待处理"
        case .done: return "已处理"
        case .postponed: return "已延后"
        case .archived: return "已归档"
        case .deleted: return "回收站"
        }
    }
}

public enum LoopType: String, Codable, CaseIterable, Sendable {
    case none = "NONE"
    case daily = "DAILY"
    case weekly = "WEEKLY"
    case monthly = "MONTHLY"

    public var titleZh: String {
        switch self {
        case .none: return "不循环"
        case .daily: return "每天"
        case .weekly: return "每周"
        case .monthly: return "每月"
        }
    }
}

public enum ActionType: String, Codable, CaseIterable, Sendable {
    case done = "DONE"
    case delay = "DELAY"
    case close = "CLOSE"

    public var titleZh: String {
        switch self {
        case .done: return "标记完成"
        case .delay: return "延后"
        case .close: return "只关卡片"
        }
    }
}

/// 强提醒卡片上的一个按钮。注意：`id` 只给界面用，不写进备份文件。
public struct NoteAction: Codable, Hashable, Sendable {
    public var text: String
    public var type: ActionType

    public init(text: String, type: ActionType = .done) {
        self.text = text
        self.type = type
    }
}

/// 一条便签。`id` 是本机 UUID，不参与备份交换。
public struct Note: Identifiable, Hashable, Sendable {
    public var id: UUID
    public var title: String
    public var remark: String
    /// 归属日期，本地日历日，yyyy-MM-dd
    public var dateKey: String
    /// 提醒的绝对时刻（Unix 毫秒），0 表示不设定时
    public var remindAt: Int64
    public var loopType: LoopType
    public var repeatEnabled: Bool
    public var repeatMinutes: Int
    public var status: NoteStatus
    public var createdAt: Int64
    public var remindCount: Int
    public var actions: [NoteAction]

    public init(
        id: UUID = UUID(),
        title: String,
        remark: String = "",
        dateKey: String,
        remindAt: Int64 = 0,
        loopType: LoopType = .none,
        repeatEnabled: Bool = false,
        repeatMinutes: Int = 15,
        status: NoteStatus = .pending,
        createdAt: Int64 = 0,
        remindCount: Int = 0,
        actions: [NoteAction] = []
    ) {
        self.id = id
        self.title = title
        self.remark = remark
        self.dateKey = dateKey
        self.remindAt = remindAt
        self.loopType = loopType
        self.repeatEnabled = repeatEnabled
        self.repeatMinutes = repeatMinutes
        self.status = status
        self.createdAt = createdAt
        self.remindCount = remindCount
        self.actions = actions
    }

    /// 卡片上实际显示的按钮；没配自定义按钮时给一个默认「完成」
    public func cardActions(defaultTitle: String = "完成") -> [NoteAction] {
        actions.isEmpty ? [NoteAction(text: defaultTitle, type: .done)] : actions
    }
}
