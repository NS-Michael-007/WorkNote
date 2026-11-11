package com.workspace.worknote.ui

import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import androidx.recyclerview.widget.RecyclerView
import com.workspace.worknote.R
import com.workspace.worknote.data.Note
import com.workspace.worknote.databinding.ItemBinNoteBinding
import com.workspace.worknote.util.TimeUtil

/**
 * 回收站的一行。
 * 普通模式：点整行等于「点开这一条」，交给页面弹恢复 / 彻底删除。
 * 多选模式：点整行就是勾选 / 取消勾选这一条。
 */
class BinAdapter(
    private val onRowClick: (Note) -> Unit,
    private val onSelectionChanged: () -> Unit
) : RecyclerView.Adapter<BinAdapter.Holder>() {

    private val items = ArrayList<Note>()
    private val selected = LinkedHashSet<Long>()
    private var selecting = false

    fun submit(list: List<Note>) {
        items.clear()
        items.addAll(list)
        val alive = items.map { it.id }.toSet()
        selected.retainAll(alive)
        notifyDataSetChanged()
        onSelectionChanged()
    }

    fun setSelecting(on: Boolean) {
        selecting = on
        if (!on) selected.clear()
        notifyDataSetChanged()
        onSelectionChanged()
    }

    fun isSelecting(): Boolean = selecting

    fun selectedIds(): List<Long> = selected.toList()

    fun selectedCount(): Int = selected.size

    fun allSelected(): Boolean = items.isNotEmpty() && selected.size == items.size

    fun selectAll(on: Boolean) {
        selected.clear()
        if (on) items.forEach { selected.add(it.id) }
        notifyDataSetChanged()
        onSelectionChanged()
    }

    override fun getItemCount(): Int = items.size

    override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): Holder =
        Holder(ItemBinNoteBinding.inflate(LayoutInflater.from(parent.context), parent, false))

    override fun onBindViewHolder(holder: Holder, position: Int) {
        holder.bind(items[position])
    }

    inner class Holder(private val binding: ItemBinNoteBinding) :
        RecyclerView.ViewHolder(binding.root) {

        fun bind(note: Note) {
            val context = binding.root.context
            binding.binTitle.text =
                note.title.ifBlank { context.getString(R.string.unnamed_note) }
            binding.binSub.text =
                note.remark.ifBlank { context.getString(R.string.st_deleted) }
            binding.binTime.text = TimeUtil.friendly(note.updatedAt)

            binding.binCheck.visibility = if (selecting) View.VISIBLE else View.GONE
            binding.binCheck.setOnCheckedChangeListener(null)
            binding.binCheck.isChecked = selected.contains(note.id)
            binding.binIcon.alpha = if (selecting) 0.75f else 0.55f

            binding.root.setOnClickListener {
                if (selecting) {
                    if (!selected.remove(note.id)) selected.add(note.id)
                    notifyItemChanged(bindingAdapterPosition)
                    onSelectionChanged()
                } else {
                    onRowClick(note)
                }
            }
        }
    }
}
