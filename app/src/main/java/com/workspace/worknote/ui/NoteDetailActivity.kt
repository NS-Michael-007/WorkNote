package com.workspace.worknote.ui

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.graphics.Typeface
import android.os.Bundle
import android.view.Gravity
import android.widget.LinearLayout
import android.widget.TextView
import android.widget.Toast
import androidx.activity.result.contract.ActivityResultContracts
import androidx.appcompat.app.AlertDialog
import androidx.core.content.ContextCompat
import com.workspace.worknote.R
import com.workspace.worknote.data.LoopType
import com.workspace.worknote.data.Note
import com.workspace.worknote.data.Status
import com.workspace.worknote.data.Store
import com.workspace.worknote.databinding.ActivityNoteDetailBinding
import com.workspace.worknote.logic.NoteActions
import com.workspace.worknote.logic.ReminderScheduler
import com.workspace.worknote.logic.UiBus
import com.workspace.worknote.settings.ThemeHelper
import com.workspace.worknote.util.TimeUtil

/** 便签详情：看全部信息，也能直接点按钮处理，还能把正文交给系统翻译应用 */
class NoteDetailActivity : BaseActivity() {

    companion object {
        const val EXTRA_NOTE_ID = "note_id"
    }

    private lateinit var binding: ActivityNoteDetailBinding
    private var noteId = 0L

    private val editLauncher =
        registerForActivityResult(ActivityResultContracts.StartActivityForResult()) { render() }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        binding = ActivityNoteDetailBinding.inflate(layoutInflater)
        setContentView(binding.root)

        noteId = intent.getLongExtra(EXTRA_NOTE_ID, 0L)

        binding.btnEdit.setOnClickListener {
            editLauncher.launch(
                Intent(this, NoteEditActivity::class.java)
                    .putExtra(NoteEditActivity.EXTRA_NOTE_ID, noteId)
            )
        }
        binding.btnDelete.setOnClickListener { confirmDelete() }
        binding.btnTranslate.setOnClickListener { translateCurrent() }

        ThemeHelper.applyPageBackground(binding.root)
        render()
    }

    override fun onResume() {
        super.onResume()
        render()
    }

    private fun render() {
        val note = Store.get(noteId)
        if (note == null) {
            finish()
            return
        }
        binding.detailTitle.text = note.title
        binding.detailRemark.text =
            note.remark.ifBlank { getString(R.string.detail_no_remark) }
        binding.detailDate.text =
            getString(R.string.detail_date_fmt, TimeUtil.dayLabel(note.dateKey))
        binding.detailTime.text = if (note.remindAt > 0L) {
            getString(R.string.detail_time_fmt, TimeUtil.friendly(note.remindAt))
        } else {
            getString(R.string.detail_time_none)
        }
        binding.detailLoop.text = getString(R.string.detail_loop_fmt, loopLabel(note.loopType))
        binding.detailRepeat.text = getString(
            R.string.detail_repeat_fmt,
            if (note.repeatEnabled) {
                getString(R.string.detail_repeat_every_fmt, note.repeatMinutes)
            } else {
                getString(R.string.detail_repeat_off)
            }
        )
        binding.detailStatus.text =
            getString(R.string.detail_status_fmt, statusLabel(note.status))

        renderActions(note)
    }

    private fun loopLabel(type: String): String = when (type) {
        LoopType.DAILY -> getString(R.string.rmd_loop_daily)
        LoopType.WEEKLY -> getString(R.string.rmd_loop_weekly)
        LoopType.MONTHLY -> getString(R.string.rmd_loop_monthly)
        else -> getString(R.string.loop_none)
    }

    private fun statusLabel(status: String): String = when (status) {
        Status.PENDING -> getString(R.string.st_pending)
        Status.READY -> getString(R.string.st_ready)
        Status.DONE -> getString(R.string.st_done)
        Status.POSTPONED -> getString(R.string.st_postponed)
        Status.ARCHIVED -> getString(R.string.st_archived)
        Status.DELETED -> getString(R.string.st_deleted)
        else -> status
    }

    private fun renderActions(note: Note) {
        val density = resources.displayMetrics.density
        val box = binding.detailActions
        box.removeAllViews()
        note.cardActions().forEachIndexed { index, action ->
            val button = TextView(this).apply {
                text = action.text.ifBlank { getString(R.string.action_done) }
                gravity = Gravity.CENTER
                textSize = 15f
                typeface = Typeface.DEFAULT_BOLD
                setTextColor(android.graphics.Color.WHITE)
                setBackgroundResource(R.drawable.bg_button_primary)
                layoutParams = LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.MATCH_PARENT, (44 * density).toInt()
                ).apply { if (index > 0) topMargin = (10 * density).toInt() }
            }
            button.setOnClickListener {
                NoteActions.apply(this, note, action)
                toast(getString(R.string.detail_handled_fmt, action.text))
                render()
            }
            box.addView(button)
        }
    }

    /** 把标题 + 备注交给系统里能翻译的应用（ACTION_PROCESS_TEXT），没有就复制到剪贴板 */
    private fun translateCurrent() {
        val note = Store.get(noteId) ?: return
        val payload = buildString {
            append(note.title)
            if (note.remark.isNotBlank()) append('\n').append(note.remark)
        }.trim()
        if (payload.isEmpty()) {
            toast(getString(R.string.translate_nothing))
            return
        }
        val intent = Intent(Intent.ACTION_PROCESS_TEXT).apply {
            type = "text/plain"
            putExtra(Intent.EXTRA_PROCESS_TEXT, payload)
            putExtra(Intent.EXTRA_PROCESS_TEXT_READONLY, true)
        }
        val handlers = packageManager.queryIntentActivities(intent, 0)
        if (handlers.isNotEmpty()) {
            startActivity(Intent.createChooser(intent, getString(R.string.translate_chooser)))
        } else {
            val clipboard = getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
            clipboard.setPrimaryClip(ClipData.newPlainText(note.title, payload))
            toast(getString(R.string.translate_copied))
        }
    }

    private fun confirmDelete() {
        AlertDialog.Builder(this)
            .setTitle(R.string.detail_delete_title)
            .setMessage(R.string.detail_delete_msg)
            .setPositiveButton(R.string.action_delete) { _, _ ->
                ReminderScheduler.cancel(this, noteId)
                Store.moveToBin(noteId)
                UiBus.notify(this)
                toast(getString(R.string.detail_deleted))
                finish()
            }
            .setNegativeButton(android.R.string.cancel, null)
            .show()
    }

    private fun toast(message: String) {
        Toast.makeText(this, message, Toast.LENGTH_SHORT).show()
    }
}
