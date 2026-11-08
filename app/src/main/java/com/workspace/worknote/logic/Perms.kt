package com.workspace.worknote.logic

import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.provider.Settings
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import com.workspace.worknote.R
import com.workspace.worknote.ui.ReminderActivity

/** 权限检查与小工具 */
object Perms {

    fun canOverlay(context: Context): Boolean = Settings.canDrawOverlays(context)

    fun canNotify(context: Context): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            val nm = context.getSystemService(NotificationManager::class.java)
            return nm?.areNotificationsEnabled() ?: true
        }
        return ContextCompat.checkSelfPermission(
            context, android.Manifest.permission.POST_NOTIFICATIONS
        ) == PackageManager.PERMISSION_GRANTED
    }

    fun ignoringBatteryOptimization(context: Context): Boolean {
        val pm = context.getSystemService(android.os.PowerManager::class.java) ?: return false
        return pm.isIgnoringBatteryOptimizations(context.packageName)
    }

    fun fullScreenIntent(context: Context) {
        val intent = Intent(context, ReminderActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        }
        runCatching { context.startActivity(intent) }
    }

    /** 强提醒用的常驻 + 全屏意图通知 */
    fun buildReminderNotification(context: Context, noteId: Long, title: String, text: String): android.app.Notification {
        val fullScreen = PendingIntent.getActivity(
            context,
            noteId.toInt(),
            Intent(context, ReminderActivity::class.java).apply {
                putExtra(ReminderService.EXTRA_NOTE_ID, noteId)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        return NotificationCompat.Builder(context, Channels.TASK)
            .setSmallIcon(R.drawable.ic_note)
            .setContentTitle(title)
            .setContentText(text)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setOngoing(true)
            .setAutoCancel(false)
            .setFullScreenIntent(fullScreen, true)
            .setContentIntent(fullScreen)
            .build()
    }

    /** 前台服务必须挂一条通知，这是系统要求，不是任务提醒 */
    fun buildServiceNotification(context: Context, title: String, text: String): android.app.Notification =
        NotificationCompat.Builder(context, Channels.REMINDER)
            .setSmallIcon(R.drawable.ic_note)
            .setContentTitle(title)
            .setContentText(text)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setOngoing(true)
            .setAutoCancel(false)
            .build()
}

/** 通知渠道 */
object Channels {
    const val REMINDER = "reminder_service"
    /**
     * 任务提醒渠道改成静音：
     * ① 渠道一旦建好，声音就改不了，所以要换 id（末尾 v2）才能生效；
     * ② 出声统一交给 Alerts，否则系统音和用户自选的铃声会一起响。
     */
    const val TASK = "task_alert_v2"

    fun ensure(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val nm = context.getSystemService(NotificationManager::class.java) ?: return

        val reminder = android.app.NotificationChannel(
            REMINDER,
            context.getString(R.string.channel_reminder),
            NotificationManager.IMPORTANCE_LOW
        ).apply {
            description = context.getString(R.string.channel_reminder_desc)
            setShowBadge(false)
        }
        val task = android.app.NotificationChannel(
            TASK,
            context.getString(R.string.channel_task),
            NotificationManager.IMPORTANCE_HIGH
        ).apply {
            description = context.getString(R.string.channel_alert_desc)
            // 静音 + 不震动：声音与震动都由 Alerts 按用户设置播放
            setSound(null, null)
            enableVibration(false)
        }
        nm.createNotificationChannel(reminder)
        nm.createNotificationChannel(task)
        // 清掉旧的带声音渠道，免得设置页里留一个用不上的「任务提醒」
        runCatching { nm.deleteNotificationChannel("task_alert") }
    }
}
