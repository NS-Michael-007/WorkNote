package com.workspace.worknote.logic

import android.content.Context
import android.content.Intent
import com.workspace.worknote.data.ActionType
import com.workspace.worknote.data.LoopType
import com.workspace.worknote.data.Note
import com.workspace.worknote.data.NoteAction
import com.workspace.worknote.data.Status
import com.workspace.worknote.data.Store
import com.workspace.worknote.settings.AppSettings
import com.workspace.worknote.util.TimeUtil
import java.util.Calendar

/** 点击强提醒卡片上的按钮后要做的全部事情 */
object NoteActions {

    /** 延后按钮顺延的分钟数，可在「我 → 闹钟与提醒」里改，默认 30 分钟 */
    fun delayMinutes(context: Context): Int = AppSettings.defaultDelayMinutes(context)

    fun apply(context: Context, note: Note, action: NoteAction) {
        val now = TimeUtil.now()
        when (action.type) {
            ActionType.DELAY -> {
                note.status = Status.POSTPONED
                note.remindAt = now + delayMinutes(context) * 60_000L
                note.updatedAt = now
                Store.update(note)
                ReminderScheduler.schedule(context, note)
            }

            ActionType.CLOSE -> {
                // 只关卡片，任务继续挂着；关掉闹钟，不再立刻响（提醒时间已经过去了）
                note.updatedAt = now
                Store.update(note)
                ReminderScheduler.cancel(context, note.id)
            }

            else -> finish(context, note, now)
        }
        UiBus.notify(context)
    }

    /** 标记完成：有循环就排下一次，没有就归档为已处理 */
    private fun finish(context: Context, note: Note, now: Long) {
        ReminderScheduler.cancel(context, note.id)
        if (note.loopType != LoopType.NONE) {
            val next = nextOccurrence(note.remindAt, note.loopType)
            note.status = Status.PENDING
            note.remindAt = next
            note.dateKey = TimeUtil.keyOf(next)
            note.remindCount = 0
            note.updatedAt = now
            Store.update(note)
            ReminderScheduler.schedule(context, note)
        } else {
            note.status = Status.DONE
            note.remindAt = 0L
            note.updatedAt = now
            Store.update(note)
        }
    }

    fun nextOccurrence(baseTs: Long, loopType: String): Long {
        val base = if (baseTs > 0L) baseTs else TimeUtil.now()
        val calendar = Calendar.getInstance().apply { timeInMillis = base }
        var guard = 0
        do {
            when (loopType) {
                LoopType.DAILY -> calendar.add(Calendar.DAY_OF_YEAR, 1)
                LoopType.WEEKLY -> calendar.add(Calendar.WEEK_OF_YEAR, 1)
                LoopType.MONTHLY -> calendar.add(Calendar.MONTH, 1)
                else -> calendar.add(Calendar.DAY_OF_YEAR, 1)
            }
            guard++
        } while (calendar.timeInMillis <= TimeUtil.now() && guard < 400)
        return calendar.timeInMillis
    }
}
