package com.workspace.worknote.ui

import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import androidx.core.content.ContextCompat
import androidx.recyclerview.widget.RecyclerView
import com.workspace.worknote.R
import com.workspace.worknote.databinding.ItemCalendarDayBinding

/** 日历模式的一个格子；day 为 0 表示这个月之前的空位 */
data class CalCell(val day: Int, val key: String, val count: Int)

/** 日历模式的整月网格：七列，点某一天在下方列出当天便签 */
class CalendarAdapter(private val onDayClick: (CalCell) -> Unit) :
    RecyclerView.Adapter<CalendarAdapter.Holder>() {

    private val items = ArrayList<CalCell>()
    private var selectedDay = 0
    private var todayKey = ""

    fun submit(cells: List<CalCell>, selected: Int, today: String) {
        items.clear()
        items.addAll(cells)
        selectedDay = selected
        todayKey = today
        notifyDataSetChanged()
    }

    override fun getItemCount(): Int = items.size

    override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): Holder =
        Holder(ItemCalendarDayBinding.inflate(LayoutInflater.from(parent.context), parent, false))

    override fun onBindViewHolder(holder: Holder, position: Int) {
        holder.bind(items[position])
    }

    inner class Holder(private val binding: ItemCalendarDayBinding) :
        RecyclerView.ViewHolder(binding.root) {

        fun bind(cell: CalCell) {
            val context = binding.root.context
            if (cell.day <= 0) {
                binding.calDay.text = ""
                binding.calDay.background = null
                binding.calCount.visibility = View.GONE
                binding.root.setOnClickListener(null)
                return
            }

            val selected = cell.day == selectedDay
            binding.calDay.text = cell.day.toString()
            binding.calDay.background = ContextCompat.getDrawable(
                context,
                if (selected) R.drawable.bg_button_primary else R.drawable.bg_field
            )
            binding.calDay.setTextColor(
                ContextCompat.getColor(
                    context,
                    when {
                        selected -> android.R.color.white
                        cell.key == todayKey -> R.color.accent
                        else -> R.color.text_primary
                    }
                )
            )
            if (cell.count > 0) {
                binding.calCount.visibility = View.VISIBLE
                binding.calCount.text = if (cell.count > 99) "99+" else cell.count.toString()
            } else {
                binding.calCount.visibility = View.GONE
            }
            binding.root.setOnClickListener { onDayClick(cell) }
        }
    }
}
