package com.workspace.worknote.ui

import android.os.Build
import android.os.Bundle
import androidx.activity.OnBackPressedCallback
import androidx.appcompat.app.AppCompatActivity
import com.workspace.worknote.data.Store
import com.workspace.worknote.databinding.ActivityReminderBinding
import com.workspace.worknote.logic.NoteActions
import com.workspace.worknote.logic.ReminderService

/** 没给悬浮窗权限时的兜底：全屏强提醒页面，同样没有关闭按钮 */
class ReminderActivity : BaseActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val binding = ActivityReminderBinding.inflate(layoutInflater)
        setContentView(binding.root)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(com.workspace.worknote.settings.AppSettings.notifyScreenOn(this))
        }
        com.workspace.worknote.logic.Alerts.fire(this)

        val noteId = intent.getLongExtra(ReminderService.EXTRA_NOTE_ID, 0L)
        val note = if (noteId > 0L) Store.get(noteId) else null
        if (note == null) {
            finish()
            return
        }

        ReminderCard.bind(binding.root, note) { action ->
            com.workspace.worknote.logic.Alerts.stop()
            NoteActions.apply(this, note, action)
            finish()
        }

        onBackPressedDispatcher.addCallback(this, object : OnBackPressedCallback(true) {
            override fun handleOnBackPressed() {
                // 返回键不允许关掉提醒，只能点卡片上的按钮
            }
        })
    }
}
