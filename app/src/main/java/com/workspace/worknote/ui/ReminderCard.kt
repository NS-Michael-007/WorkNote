package com.workspace.worknote.ui

import android.graphics.Color
import android.graphics.Typeface
import android.view.Gravity
import android.view.View
import android.view.ViewGroup.LayoutParams.MATCH_PARENT
import android.widget.LinearLayout
import android.widget.TextView
import com.workspace.worknote.R
import com.workspace.worknote.data.LoopType
import com.workspace.worknote.data.Note
import com.workspace.worknote.data.NoteAction
import com.workspace.worknote.util.TimeUtil

/** 强提醒卡片装填：标题、备注、这条便签自己的按钮 */
object ReminderCard {

    fun bind(root: View, note: Note, onAction: (NoteAction) -> Unit) {
        val density = root.resources.displayMetrics.density
        val dp44 = (44 * density).toInt()
        val dp12 = (12 * density).toInt()

        root.findViewById<TextView>(R.id.cardTitle).text = note.title.ifBlank { root.context.getString(R.string.unnamed_note) }
        root.findViewById<TextView>(R.id.cardSub).text =
            note.remark.ifBlank { root.context.getString(R.string.reminder_default_remark) }
        root.findViewById<TextView>(R.id.cardMeta).text = metaText(note)

        val box = root.findViewById<LinearLayout>(R.id.cardButtons)
        box.removeAllViews()

        note.cardActions().forEachIndexed { index, action ->
            val button = TextView(root.context).apply {
                text = action.text.ifBlank { root.context.getString(R.string.action_done) }
                gravity = Gravity.CENTER
                setTextColor(Color.WHITE)
                textSize = 15f
                typeface = Typeface.DEFAULT_BOLD
                setBackgroundResource(R.drawable.bg_button_primary)
                layoutParams = LinearLayout.LayoutParams(MATCH_PARENT, dp44).apply {
                    if (index > 0) topMargin = dp12
                }
            }
            button.setOnClickListener { onAction(action) }
            box.addView(button)
        }
    }

    private fun metaText(note: Note): String {
        val ctx = com.workspace.worknote.util.AppCtx.context
        val parts = ArrayList<String>()
        if (note.remindAt > 0L) {
            parts.add(ctx.getString(R.string.rmd_meta_time, TimeUtil.friendly(note.remindAt)))
        } else if (note.dateKey.isNotBlank()) {
            parts.add(ctx.getString(R.string.rmd_meta_date, TimeUtil.dayLabel(note.dateKey)))
        }
        when (note.loopType) {
            LoopType.DAILY -> parts.add(ctx.getString(R.string.rmd_meta_daily))
            LoopType.WEEKLY -> parts.add(ctx.getString(R.string.rmd_meta_weekly))
            LoopType.MONTHLY -> parts.add(ctx.getString(R.string.rmd_meta_monthly))
        }
        if (note.repeatEnabled) parts.add(ctx.getString(R.string.rmd_meta_repeat, note.repeatMinutes))
        if (note.remindCount > 1) parts.add(ctx.getString(R.string.rmd_meta_count, note.remindCount))
        return parts.joinToString("｜")
    }
}
