package com.workspace.worknote.logic

import android.app.Service
import android.content.Context
import android.content.Intent
import android.graphics.PixelFormat
import android.os.Build
import android.os.IBinder
import android.view.KeyEvent
import android.view.LayoutInflater
import android.view.View
import android.view.WindowManager
import com.workspace.worknote.R
import com.workspace.worknote.data.Note
import com.workspace.worknote.data.Store
import com.workspace.worknote.ui.ReminderCard

/**
 * 强提醒服务：前台服务 + 屏幕置顶卡片。
 * 卡片没有关闭入口，只能点便签自己的按钮。
 * 没给悬浮窗权限时退回到全屏提醒页面。
 */
class ReminderService : Service() {

    companion object {
        const val EXTRA_NOTE_ID = "note_id"
        private const val FOREGROUND_ID = 1101

        fun start(context: Context, noteId: Long) {
            val intent = Intent(context, ReminderService::class.java)
                .putExtra(EXTRA_NOTE_ID, noteId)
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    context.startForegroundService(intent)
                } else {
                    context.startService(intent)
                }
            } catch (e: Exception) {
                // 后台限制起不来时，用全屏提醒页面兜底
                Perms.fullScreenIntent(context)
            }
        }
    }

    private var windowManager: WindowManager? = null
    private var overlayView: View? = null

    override fun onCreate() {
        super.onCreate()
        windowManager = getSystemService(WindowManager::class.java)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val noteId = intent?.getLongExtra(EXTRA_NOTE_ID, 0L) ?: 0L
        val note = if (noteId > 0L) Store.get(noteId) else null

        startForeground(
            FOREGROUND_ID,
            Perms.buildServiceNotification(
                this,
                note?.title ?: getString(R.string.app_name),
                note?.remark.orEmpty().ifBlank { getString(R.string.reminder_default_remark) }
            )
        )

        if (note != null && overlayView == null) showCard(note)
        return START_NOT_STICKY
    }

    private fun showCard(note: Note) {
        val manager = windowManager
        if (manager == null || !Perms.canOverlay(this)) {
            Perms.fullScreenIntent(this)
            return
        }

        val root = LayoutInflater.from(this).inflate(R.layout.overlay_reminder, null)
        ReminderCard.bind(root, note) { action ->
            NoteActions.apply(this, note, action)
            dismiss()
        }
        root.isFocusableInTouchMode = true
        root.setOnKeyListener { _, keyCode, _ -> keyCode == KeyEvent.KEYCODE_BACK }

        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
            WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                (if (com.workspace.worknote.settings.AppSettings.notifyScreenOn(this))
                    WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON else 0),
            PixelFormat.TRANSLUCENT
        )
        try {
            manager.addView(root, params)
            overlayView = root
            root.requestFocus()
            Alerts.fire(this)
        } catch (e: Exception) {
            Perms.fullScreenIntent(this)
        }
    }

    private fun dismiss() {
        Alerts.stop()
        overlayView?.let { view -> runCatching { windowManager?.removeView(view) } }
        overlayView = null
        stopForeground(Service.STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    override fun onDestroy() {
        Alerts.stop()
        overlayView?.let { view -> runCatching { windowManager?.removeView(view) } }
        overlayView = null
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null
}
