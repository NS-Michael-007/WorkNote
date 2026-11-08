package com.workspace.worknote.ui

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Bundle
import android.view.View
import androidx.core.content.ContextCompat
import androidx.fragment.app.Fragment
import androidx.recyclerview.widget.LinearLayoutManager
import com.workspace.worknote.R
import com.workspace.worknote.data.Note
import com.workspace.worknote.data.Store
import com.workspace.worknote.databinding.FragmentScheduleBinding
import com.workspace.worknote.logic.UiBus
import com.workspace.worknote.settings.ThemeHelper
import com.workspace.worknote.util.TimeUtil

/** 日程：纵向罗列当月 1 号到月末，点日期展开当天便签 */
class ScheduleFragment : Fragment(R.layout.fragment_schedule) {

    private var binding: FragmentScheduleBinding? = null
    private var year = TimeUtil.todayYear()
    private var month = TimeUtil.todayMonth()
    private val expandedKeys = mutableSetOf<String>()
    private var rows: List<DayRow> = emptyList()

    private val adapter = DateRowAdapter(
        onToggle = { index -> toggle(index) },
        onNoteClick = { note -> openDetail(note) }
    )

    private val refreshReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            load()
        }
    }

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)
        val viewBinding = FragmentScheduleBinding.bind(view)
        binding = viewBinding

        viewBinding.dayList.layoutManager = LinearLayoutManager(requireContext())
        viewBinding.dayList.adapter = adapter
        // 只有设了背景图才铺半透明面板；纯色底时保持原来的样子
        viewBinding.dayList.setBackgroundResource(
            if (ThemeHelper.hasBackground(requireContext())) R.drawable.bg_frost_panel
            else R.color.page_bg
        )

        // 年月一次性选好（滚轮选年 + 十二宫格选月），不再点箭头一月一月翻
        viewBinding.btnPickMonth.setOnClickListener {
            MonthPicker.show(requireContext(), year, month) { pickedYear, pickedMonth ->
                year = pickedYear
                month = pickedMonth
                expandedKeys.clear()
                renderMonthLabel()
                load()
            }
        }

        renderMonthLabel()
        load()
    }

    override fun onResume() {
        super.onResume()
        load()
    }

    override fun onStart() {
        super.onStart()
        ContextCompat.registerReceiver(
            requireContext(),
            refreshReceiver,
            IntentFilter(UiBus.ACTION_REFRESH),
            ContextCompat.RECEIVER_NOT_EXPORTED
        )
    }

    override fun onStop() {
        super.onStop()
        runCatching { requireContext().unregisterReceiver(refreshReceiver) }
    }

    override fun onDestroyView() {
        super.onDestroyView()
        binding = null
    }

    private fun renderMonthLabel() {
        binding?.btnPickMonth?.text =
            getString(R.string.month_fmt, year, month) + " ▾"
    }

    private fun load() {
        val counts = Store.activeCounts()
        val days = TimeUtil.daysInMonth(year, month)
        rows = (1..days).map { day ->
            val key = TimeUtil.keyOf(year, month, day)
            val expanded = expandedKeys.contains(key)
            val notes = if (expanded) Store.forDate(key) else emptyList()
            DayRow(day, key, counts[key] ?: 0, expanded, notes)
        }
        adapter.submit(rows)
    }

    private fun toggle(index: Int) {
        if (index !in rows.indices) return
        val row = rows[index]
        if (row.expanded) {
            expandedKeys.remove(row.key)
            row.expanded = false
            row.notes = emptyList()
        } else {
            expandedKeys.add(row.key)
            row.expanded = true
            row.notes = Store.forDate(row.key)
        }
        adapter.notifyItemChanged(index)
    }

    private fun openDetail(note: Note) {
        startActivity(
            Intent(requireContext(), NoteDetailActivity::class.java)
                .putExtra(NoteDetailActivity.EXTRA_NOTE_ID, note.id)
        )
    }
}
