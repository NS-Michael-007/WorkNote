package com.workspace.worknote.ui

import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import androidx.recyclerview.widget.RecyclerView
import com.workspace.worknote.R
import com.workspace.worknote.data.Note
import com.workspace.worknote.databinding.ItemDateRowBinding
import com.workspace.worknote.databinding.ItemNoteBinding
import com.workspace.worknote.util.TimeUtil

/** 日程页的一行：1 号、2 号 … 可以展开显示当天便签 */
data class DayRow(
    val day: Int,
    val key: String,
    val count: Int,
    var expanded: Boolean,
    var notes: List<Note>
)

class DateRowAdapter(
    private val onToggle: (Int) -> Unit,
    private val onNoteClick: (Note) -> Unit
) : RecyclerView.Adapter<DateRowAdapter.Holder>() {

    private val items = ArrayList<DayRow>()

    fun submit(rows: List<DayRow>) {
        items.clear()
        items.addAll(rows)
        notifyDataSetChanged()
    }

    override fun getItemCount(): Int = items.size

    override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): Holder =
        Holder(ItemDateRowBinding.inflate(LayoutInflater.from(parent.context), parent, false))

    override fun onBindViewHolder(holder: Holder, position: Int) {
        holder.bind(items[position], position)
    }

    inner class Holder(private val binding: ItemDateRowBinding) :
        RecyclerView.ViewHolder(binding.root) {

        fun bind(row: DayRow, position: Int) {
            val year = row.key.substring(0, 4).toInt()
            val month = row.key.substring(5, 7).toInt()

            binding.dayNum.text = binding.root.context.getString(R.string.day_of_month_fmt, row.day)
            binding.dayWeek.text = TimeUtil.weekdayLabel(year, month, row.day)

            if (row.count > 0) {
                binding.dayCount.visibility = View.VISIBLE
                binding.dayCount.text = if (row.count > 99) "99+" else row.count.toString()
            } else {
                binding.dayCount.visibility = View.GONE
            }

            binding.dayArrow.rotation = if (row.expanded) 90f else 0f
            binding.dateRow.setOnClickListener { onToggle(position) }

            binding.dayChildren.removeAllViews()
            if (row.expanded) {
                if (row.notes.isEmpty()) {
                    val empty = android.widget.TextView(binding.root.context).apply {
                        text = binding.root.context.getString(R.string.date_empty_hint)
                        setTextColor(
                            binding.root.context.getColor(R.color.text_secondary)
                        )
                        textSize = 12f
                        setPadding(16.dp(binding.root.context), 8.dp(binding.root.context),
                            16.dp(binding.root.context), 12.dp(binding.root.context))
                    }
                    binding.dayChildren.addView(empty)
                } else {
                    val inflater = LayoutInflater.from(binding.root.context)
                    row.notes.forEach { note ->
                        val item = ItemNoteBinding.inflate(inflater, binding.dayChildren, false)
                        item.noteTitle.text = note.title
                        item.noteSub.text = NoteAdapter.subText(note)
                        item.noteTime.text = NoteAdapter.timeText(note)
                        val badge = NoteAdapter.badgeText(note)
                        if (badge.isNullOrEmpty()) {
                            item.noteBadge.visibility = View.GONE
                        } else {
                            item.noteBadge.visibility = View.VISIBLE
                            item.noteBadge.text = badge
                        }
                        item.root.setOnClickListener { onNoteClick(note) }
                        binding.dayChildren.addView(item.root)
                    }
                }
                binding.dayChildren.visibility = View.VISIBLE
            } else {
                binding.dayChildren.visibility = View.GONE
            }
        }

        private fun Int.dp(context: android.content.Context): Int =
            (this * context.resources.displayMetrics.density).toInt()
    }
}
