package com.workspace.worknote.data

/** 便签状态 */
object Status {
    const val PENDING = "PENDING"       // 待提醒
    const val READY = "READY"           // 待处理（已弹出过提醒，未处理）
    const val DONE = "DONE"             // 已处理
    const val POSTPONED = "POSTPONED"   // 已延后
    const val ARCHIVED = "ARCHIVED"     // 已归档
    const val DELETED = "DELETED"       // 回收站
}

/** 循环方式 */
object LoopType {
    const val NONE = "NONE"
    const val DAILY = "DAILY"
    const val WEEKLY = "WEEKLY"
    const val MONTHLY = "MONTHLY"
}

/** 自定义按钮动作类型 */
object ActionType {
    const val DONE = "DONE"     // 标记完成
    const val DELAY = "DELAY"   // 延后
    const val CLOSE = "CLOSE"   // 仅关闭卡片，保持待处理
}

/** 便签上自定义的一个按钮：文字 + 动作 */
data class NoteAction(
    val text: String = "",
    val type: String = ActionType.DONE
)

/** 便签实体（对应 notes 表） */
data class Note(
    var id: Long = 0L,
    var title: String = "",
    var remark: String = "",
    var dateKey: String = "",              // 关联日期 yyyy-MM-dd
    var remindAt: Long = 0L,               // 提醒时间戳（毫秒），0 表示不设定时
    var loopType: String = LoopType.NONE,
    var repeatEnabled: Boolean = false,
    var repeatMinutes: Int = 15,
    var status: String = Status.PENDING,
    var actions: List<NoteAction> = emptyList(),
    var createdAt: Long = 0L,
    var updatedAt: Long = 0L,
    var remindCount: Int = 0
) {
    val isActive: Boolean
        get() = status == Status.PENDING || status == Status.READY || status == Status.POSTPONED

    /** 强提醒卡片上实际要显示的按钮，没配自定义按钮时给一个默认的 */
    fun cardActions(): List<NoteAction> =
        if (actions.isEmpty()) listOf(NoteAction(com.workspace.worknote.util.AppCtx.context.getString(com.workspace.worknote.R.string.action_done), ActionType.DONE)) else actions
}
