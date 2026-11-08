package com.workspace.worknote.ui

import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import androidx.recyclerview.widget.RecyclerView
import com.workspace.worknote.R
import com.workspace.worknote.data.LoopType
import com.workspace.worknote.data.Note
import com.workspace.worknote.data.Status
import com.workspace.worknote.databinding.ItemNoteBinding
import com.workspace.worknote.util.AppCtx
import com.workspace.worknote.util.TimeUtil

/** 仿微信会话列表的一行 */
class NoteAdapter(
    private val onClick: (Note) -> Unit
) : RecyclerView.Adapter<NoteAdapter.Holder>() {

    private val items = ArrayList<Note>()

    fun submit(list: List<Note>) {
        items.clear()
        items.addAll(list)
        notifyDataSetChanged()
    }

    override fun getItemCount(): Int = items.size

    override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): Holder =
        Holder(ItemNoteBinding.inflate(LayoutInflater.from(parent.context), parent, false))

    override fun onBindViewHolder(holder: Holder, position: Int) {
        holder.bind(items[position])
    }

    inner class Holder(private val binding: ItemNoteBinding) :
        RecyclerView.ViewHolder(binding.root) {

        fun bind(note: Note) {
            binding.noteTitle.text = note.title
            binding.noteSub.text = subText(note)
            binding.noteTime.text = timeText(note)
            val badge = badgeText(note)
            if (badge.isNullOrEmpty()) {
                binding.noteBadge.visibility = View.GONE
            } else {
                binding.noteBadge.visibility = View.VISIBLE
                binding.noteBadge.text = badge
            }
            binding.noteIcon.alpha = if (note.isActive) 1f else 0.55f
            binding.root.setOnClickListener { onClick(note) }
        }
    }

    companion object {

        fun subText(note: Note): String = when {
            note.remark.isNotBlank() -> note.remark
            note.status == Status.DONE -> AppCtx.context.getString(R.string.st_done)
            note.status == Status.ARCHIVED -> AppCtx.context.getString(R.string.st_archived)
            note.status == Status.READY -> AppCtx.context.getString(R.string.st_ready)
            note.loopType != LoopType.NONE -> AppCtx.context.getString(R.string.looping_label)
            else -> AppCtx.context.getString(R.string.st_pending)
        }

        fun badgeText(note: Note): String? = when (note.status) {
            Status.READY -> note.remindCount.coerceAtLeast(1).toString()
            Status.PENDING -> AppCtx.context.getString(R.string.badge_pending)
            else -> null
        }

        fun timeText(note: Note): String = when {
            note.remindAt > 0L -> TimeUtil.friendly(note.remindAt)
            note.status == Status.DONE -> AppCtx.context.getString(R.string.st_done)
            note.dateKey.isNotBlank() -> TimeUtil.dayLabel(note.dateKey)
            else -> AppCtx.context.getString(R.string.date_not_set)
        }
    }
}
