package com.workspace.worknote.logic

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import com.workspace.worknote.data.Note
import com.workspace.worknote.data.Store
import com.workspace.worknote.settings.AppSettings

/** 定时 / 循环 / 重弹 统一走系统闹钟，一个便签对应一个闹钟 */
object ReminderScheduler {

    const val ACTION_ALARM = "com.workspace.worknote.ALARM"
    const val EXTRA_NOTE_ID = "note_id"

    fun canScheduleExact(context: Context): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return true
        val am = context.getSystemService(AlarmManager::class.java) ?: return false
        return am.canScheduleExactAlarms()
    }

    private fun pendingIntent(context: Context, noteId: Long): PendingIntent {
        val intent = Intent(context, ReminderReceiver::class.java).apply {
            action = ACTION_ALARM
            putExtra(EXTRA_NOTE_ID, noteId)
        }
        return PendingIntent.getBroadcast(
            context,
            noteId.toInt(),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    fun cancel(context: Context, noteId: Long) {
        val am = context.getSystemService(AlarmManager::class.java) ?: return
        runCatching { am.cancel(pendingIntent(context, noteId)) }
    }

    fun schedule(context: Context, note: Note) {
        if (note.id <= 0L) return
        cancel(context, note.id)
        if (!note.isActive) return
        if (note.remindAt <= 0L) return

        val am = context.getSystemService(AlarmManager::class.java) ?: return
        val triggerAt = maxOf(note.remindAt, System.currentTimeMillis() + 500L)
        val operation = pendingIntent(context, note.id)
        try {
            if (AppSettings.useExactAlarm(context) && canScheduleExact(context)) {
                am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAt, operation)
            } else {
                am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAt, operation)
            }
        } catch (e: SecurityException) {
            am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAt, operation)
        }
    }

    /** 恢复备份、开机、升级后统一重排全部闹钟 */
    fun rescheduleAll(context: Context) {
        Store.all().forEach { schedule(context, it) }
    }
}
