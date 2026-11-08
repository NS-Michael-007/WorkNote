package com.workspace.worknote.logic

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import com.workspace.worknote.data.Status
import com.workspace.worknote.data.Store
import com.workspace.worknote.util.TimeUtil

/** 闹钟到点：改状态、排重弹、拉起强提醒 */
class ReminderReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        val noteId = intent.getLongExtra(ReminderScheduler.EXTRA_NOTE_ID, 0L)
        if (noteId <= 0L) return
        val note = Store.get(noteId) ?: return
        if (!note.isActive) return

        note.status = Status.READY
        note.remindCount += 1
        note.updatedAt = TimeUtil.now()

        // 未处理就再弹：只有开了这个开关才继续往下排，否则立刻注销闹钟，避免 0.5 秒后又弹一次
        if (note.repeatEnabled) {
            val interval = note.repeatMinutes.coerceAtLeast(1) * 60_000L
            note.remindAt = TimeUtil.now() + interval
            Store.update(note)
            ReminderScheduler.schedule(context, note)
        } else {
            Store.update(note)
            ReminderScheduler.cancel(context, note.id)
        }

        ReminderService.start(context, noteId)
        UiBus.notify(context)
    }
}
