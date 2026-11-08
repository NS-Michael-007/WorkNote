package com.workspace.worknote.ui

import android.app.DatePickerDialog
import android.app.TimePickerDialog
import android.graphics.Typeface
import android.os.Bundle
import android.view.Gravity
import android.widget.EditText
import android.widget.LinearLayout
import android.widget.TextView
import android.widget.Toast
import androidx.appcompat.app.AlertDialog
import androidx.appcompat.app.AppCompatActivity
import androidx.core.content.ContextCompat
import com.workspace.worknote.R
import com.workspace.worknote.data.ActionType
import com.workspace.worknote.data.LoopType
import com.workspace.worknote.data.Note
import com.workspace.worknote.data.NoteAction
import com.workspace.worknote.data.Status
import com.workspace.worknote.data.Store
import com.workspace.worknote.databinding.ActivityNoteEditBinding
import com.workspace.worknote.logic.ReminderScheduler
import com.workspace.worknote.logic.UiBus
import com.workspace.worknote.settings.AppSettings
import com.workspace.worknote.util.TimeUtil
import java.util.Calendar

/** 新建 / 编辑便签：内容、提醒方式（可多选组合）、每条便签自己的按钮 */
class NoteEditActivity : BaseActivity() {

    companion object {
        const val EXTRA_NOTE_ID = "note_id"
    }

    private lateinit var binding: ActivityNoteEditBinding
    private var existing: Note? = null
    private var dateTs = 0L
    private var remindAt = 0L
    private var loopType = LoopType.NONE
    private val actionRows = ArrayList<ActionRow>()

    private class ActionRow(
        val container: LinearLayout,
        val input: EditText,
        val typeView: TextView,
        var type: String
    )

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        binding = ActivityNoteEditBinding.inflate(layoutInflater)
        setContentView(binding.root)
        com.workspace.worknote.settings.ThemeHelper.applyPageBackground(binding.root)

        val noteId = intent.getLongExtra(EXTRA_NOTE_ID, 0L)
        val note = if (noteId > 0L) Store.get(noteId) else null
        existing = note

        binding.btnBack.setOnClickListener { finish() }
        binding.editTitle.setText(if (note == null) R.string.note_edit_new else R.string.note_edit_edit)

        val defaultTs = TimeUtil.epochOf(
            TimeUtil.todayYear(), TimeUtil.todayMonth(), TimeUtil.todayDay(), 9, 0
        )
        dateTs = defaultTs
        remindAt = defaultTs

        if (note != null) {
            binding.inputTitle.setText(note.title)
            binding.inputRemark.setText(note.remark)
            TimeUtil.parseKey(note.dateKey)?.let { dateTs = it.timeInMillis }
            if (note.remindAt > 0L) remindAt = note.remindAt
            loopType = if (note.loopType == LoopType.NONE) LoopType.DAILY else note.loopType
            binding.swTimed.isChecked = note.remindAt > 0L
            binding.swLoop.isChecked = note.loopType != LoopType.NONE
            binding.swRepeat.isChecked = note.repeatEnabled
            binding.inputInterval.setText(note.repeatMinutes.toString())
            note.actions.forEach { addActionRow(it) }
        } else {
            binding.swTimed.isChecked = true
            binding.swLoop.isChecked = false
            binding.swRepeat.isChecked = false
            binding.inputInterval.setText(AppSettings.defaultRepeatMinutes(this).toString())
        }

        if (actionRows.isEmpty()) {
            addActionRow(NoteAction(getString(R.string.action_done), ActionType.DONE))
            addActionRow(
                NoteAction(
                    getString(R.string.action_delay, AppSettings.defaultDelayMinutes(this)),
                    ActionType.DELAY
                )
            )
        }

        binding.swTimed.setOnCheckedChangeListener { _, _ -> updateEnables() }
        binding.swLoop.setOnCheckedChangeListener { _, _ -> updateEnables() }
        binding.swRepeat.setOnCheckedChangeListener { _, _ -> updateEnables() }

        binding.inputDate.setOnClickListener { pickDate() }
        binding.inputTime.setOnClickListener { if (binding.swTimed.isChecked) pickTime() }
        binding.inputLoop.setOnClickListener { if (binding.swLoop.isChecked) pickLoop() }
        binding.btnAddAction.setOnClickListener { addActionRow(NoteAction("", ActionType.DONE)) }
        binding.btnSave.setOnClickListener { save() }

        updateEnables()
        updateLabels()
    }

    private fun updateEnables() {
        val timed = binding.swTimed.isChecked
        binding.inputTime.isEnabled = timed
        binding.inputTime.alpha = if (timed) 1f else 0.5f

        val loop = binding.swLoop.isChecked
        binding.inputLoop.isEnabled = loop
        binding.inputLoop.alpha = if (loop) 1f else 0.5f

        val repeat = binding.swRepeat.isChecked
        binding.inputInterval.isEnabled = repeat
        binding.inputInterval.alpha = if (repeat) 1f else 0.5f
    }

    private fun updateLabels() {
        binding.inputDate.text = TimeUtil.fullDateLabel(TimeUtil.keyOf(dateTs))
        binding.inputTime.text =
            if (remindAt > 0L) TimeUtil.fullDateTime(remindAt) else getString(R.string.pick_time_hint)
        binding.inputLoop.text = loopLabel(loopType)
    }

    private fun loopLabel(type: String): String = when (type) {
        LoopType.DAILY -> getString(R.string.loop_daily)
        LoopType.WEEKLY -> getString(R.string.loop_weekly)
        LoopType.MONTHLY -> getString(R.string.loop_monthly)
        else -> getString(R.string.loop_none)
    }

    /** 关联日期：年 / 月 / 日 三档滚轮，「今天」一键回到当天 */
    private fun pickDate() {
        WheelPickerDialog.showDate(this, if (dateTs > 0L) dateTs else remindAt) { picked ->
            dateTs = picked
            remindAt = picked
            updateLabels()
        }
    }

    /** 提醒时间：年 / 月 / 日 + 时 / 分，年月日时都能直接翻，「今天」一键把日期落到当天 */
    private fun pickTime() {
        WheelPickerDialog.showDateTime(this, if (remindAt > 0L) remindAt else dateTs) { picked ->
            remindAt = picked
            dateTs = picked
            updateLabels()
        }
    }

    private fun pickLoop() {
        val labels = arrayOf(getString(R.string.rmd_loop_daily), getString(R.string.rmd_loop_weekly), getString(R.string.rmd_loop_monthly))
        val values = arrayOf(LoopType.DAILY, LoopType.WEEKLY, LoopType.MONTHLY)
        val selected = values.indexOf(loopType).coerceAtLeast(0)
        AlertDialog.Builder(this)
            .setTitle(R.string.loop_dialog)
            .setSingleChoiceItems(labels, selected) { dialog, which ->
                loopType = values[which]
                binding.inputLoop.text = loopLabel(loopType)
                dialog.dismiss()
            }
            .show()
    }

    private fun pickActionType(row: ActionRow) {
        val labels = arrayOf(
            getString(R.string.action_type_done_full),
            getString(R.string.action_type_delay_full, AppSettings.defaultDelayMinutes(this)),
            getString(R.string.action_type_close_full)
        )
        val values = arrayOf(ActionType.DONE, ActionType.DELAY, ActionType.CLOSE)
        val selected = values.indexOf(row.type).coerceAtLeast(0)
        AlertDialog.Builder(this)
            .setTitle(R.string.action_type_dialog)
            .setSingleChoiceItems(labels, selected) { dialog, which ->
                row.type = values[which]
                row.typeView.text = actionTypeLabel(values[which])
                dialog.dismiss()
            }
            .show()
    }

    private fun actionTypeLabel(type: String): String = when (type) {
        ActionType.DELAY -> getString(R.string.action_delay_label)
        ActionType.CLOSE -> getString(R.string.action_close_label)
        else -> getString(R.string.action_done_label)
    }

    private fun addActionRow(action: NoteAction) {
        val density = resources.displayMetrics.density
        fun dp(value: Int): Int = (value * density).toInt()

        val row = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, dp(44)
            ).apply { bottomMargin = dp(10) }
        }

        val input = EditText(this).apply {
            hint = getString(R.string.action_btn_hint)
            setText(action.text)
            textSize = 14f
            setSingleLine(true)
            setTextColor(ContextCompat.getColor(this@NoteEditActivity, R.color.text_primary))
            setHintTextColor(ContextCompat.getColor(this@NoteEditActivity, R.color.text_secondary))
            setBackgroundResource(R.drawable.bg_field)
            setPadding(dp(12), 0, dp(12), 0)
            layoutParams = LinearLayout.LayoutParams(
                0, LinearLayout.LayoutParams.MATCH_PARENT, 1f
            )
        }

        val typeView = TextView(this).apply {
            text = actionTypeLabel(action.type)
            gravity = Gravity.CENTER
            textSize = 13f
            typeface = Typeface.DEFAULT_BOLD
            setTextColor(ContextCompat.getColor(this@NoteEditActivity, R.color.accent))
            setBackgroundResource(R.drawable.bg_field)
            setPadding(dp(12), 0, dp(12), 0)
            isClickable = true
            isFocusable = true
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT, LinearLayout.LayoutParams.MATCH_PARENT
            ).apply { marginStart = dp(8) }
        }

        val holder = ActionRow(row, input, typeView, action.type)
        typeView.setOnClickListener { pickActionType(holder) }

        val delete = TextView(this).apply {
            text = getString(R.string.action_delete)
            gravity = Gravity.CENTER
            textSize = 13f
            setTextColor(ContextCompat.getColor(this@NoteEditActivity, R.color.badge_bg))
            setPadding(dp(8), 0, dp(4), 0)
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT, LinearLayout.LayoutParams.MATCH_PARENT
            ).apply { marginStart = dp(8) }
            isClickable = true
            isFocusable = true
            setOnClickListener {
                binding.actionsContainer.removeView(row)
                actionRows.remove(holder)
            }
        }

        row.addView(input)
        row.addView(typeView)
        row.addView(delete)
        binding.actionsContainer.addView(row)
        actionRows.add(holder)
    }

    private fun save() {
        val title = binding.inputTitle.text.toString().trim()
        if (title.isEmpty()) {
            toast(getString(R.string.err_title_required))
            return
        }
        if (binding.swTimed.isChecked && remindAt <= 0L) {
            toast(getString(R.string.err_time_required))
            return
        }

        val now = TimeUtil.now()
        val note = existing ?: Note(createdAt = now)
        note.title = title
        note.remark = binding.inputRemark.text.toString().trim()
        note.dateKey = TimeUtil.keyOf(dateTs)
        note.loopType = if (binding.swLoop.isChecked) loopType else LoopType.NONE
        note.repeatEnabled = binding.swRepeat.isChecked
        note.repeatMinutes = binding.inputInterval.text.toString().toIntOrNull()?.coerceIn(1, 1440) ?: 15
        note.remindAt = if (binding.swTimed.isChecked) remindAt else 0L
        note.actions = actionRows
            .map { NoteAction(it.input.text.toString().trim(), it.type) }
            .filter { it.text.isNotBlank() }
        note.updatedAt = now
        if (note.status == Status.DELETED) note.status = Status.PENDING
        if (note.remindAt > 0L && note.status != Status.READY) note.status = Status.PENDING

        if (note.id > 0L) {
            Store.update(note)
        } else {
            note.id = Store.insert(note)
        }
        ReminderScheduler.cancel(this, note.id)
        ReminderScheduler.schedule(this, note)
        UiBus.notify(this)

        setResult(RESULT_OK)
        finish()
    }

    private fun toast(message: String) {
        Toast.makeText(this, message, Toast.LENGTH_SHORT).show()
    }
}
