package com.workspace.worknote.ui

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Bundle
import android.view.GestureDetector
import android.view.MotionEvent
import android.view.View
import android.widget.LinearLayout
import android.widget.TextView
import kotlin.math.abs
import androidx.appcompat.app.AlertDialog
import androidx.core.content.ContextCompat
import androidx.fragment.app.Fragment
import androidx.recyclerview.widget.GridLayoutManager
import androidx.recyclerview.widget.LinearLayoutManager
import com.workspace.worknote.R
import com.workspace.worknote.data.Note
import com.workspace.worknote.data.Store
import com.workspace.worknote.databinding.FragmentScheduleBinding
import com.workspace.worknote.databinding.ItemNoteBinding
import com.workspace.worknote.logic.UiBus
import com.workspace.worknote.settings.AppSettings
import com.workspace.worknote.settings.ThemeHelper
import com.workspace.worknote.util.TimeUtil
import java.util.Calendar

/**
 * 日程：两种显示模式，看的是同一份数据。
 * 垂直模式——当月 1 号到月末纵向罗列，点某天展开当天便签；
 * 日历模式——整月七列网格，点某天在网格下方列出当天便签。
 * 两种模式都能左右滑动翻月：左滑下一个月，右滑上一个月。
 */
class ScheduleFragment : Fragment(R.layout.fragment_schedule) {

    private var binding: FragmentScheduleBinding? = null
    private var year = TimeUtil.todayYear()
    private var month = TimeUtil.todayMonth()
    private var mode = AppSettings.SCHEDULE_LIST
    private var selectedDay = TimeUtil.todayDay()
    private val expandedKeys = mutableSetOf<String>()
    private var rows: List<DayRow> = emptyList()
    private var calCells: List<CalCell> = emptyList()

    private val adapter = DateRowAdapter(
        onToggle = { index -> toggle(index) },
        onNoteClick = { note -> openDetail(note) }
    )

    private val calendarAdapter = CalendarAdapter { cell ->
        selectedDay = cell.day
        submitCalendar()
    }

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

        viewBinding.calendarGrid.layoutManager = GridLayoutManager(requireContext(), 7)
        viewBinding.calendarGrid.adapter = calendarAdapter
        viewBinding.calendarGrid.isNestedScrollingEnabled = false

        // 两种模式都支持左右滑动翻月：左滑下个月、右滑上个月
        attachMonthSwipe(viewBinding.dayList)
        attachMonthSwipe(viewBinding.calendarScroll)
        attachMonthSwipe(viewBinding.calendarGrid)

        // 年月一次性选好（滚轮选年 + 十二宫格选月），不再点箭头一月一月翻
        viewBinding.btnPickMonth.setOnClickListener {
            MonthPicker.show(requireContext(), year, month) { pickedYear, pickedMonth ->
                year = pickedYear
                month = pickedMonth
                expandedKeys.clear()
                selectedDay = if (pickedYear == TimeUtil.todayYear() && pickedMonth == TimeUtil.todayMonth())
                    TimeUtil.todayDay() else 1
                renderMonthLabel()
                load()
            }
        }
        viewBinding.btnDisplayMode.setOnClickListener { showModeDialog() }

        mode = AppSettings.scheduleMode(requireContext())
        if (mode != AppSettings.SCHEDULE_CALENDAR) mode = AppSettings.SCHEDULE_LIST
        applyMode()
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

    // ---------------- 显示模式 ----------------

    private fun showModeDialog() {
        val labels = arrayOf(
            getString(R.string.sched_mode_list),
            getString(R.string.sched_mode_calendar)
        )
        val values = arrayOf(AppSettings.SCHEDULE_LIST, AppSettings.SCHEDULE_CALENDAR)
        val current = values.indexOf(mode).coerceAtLeast(0)
        AlertDialog.Builder(requireContext())
            .setTitle(R.string.sched_mode_title)
            .setSingleChoiceItems(labels, current) { dialog, which ->
                mode = values[which]
                AppSettings.setScheduleMode(requireContext(), mode)
                dialog.dismiss()
                applyMode()
                load()
            }
            .setNegativeButton(android.R.string.cancel, null)
            .show()
    }

    private fun applyMode() {
        val viewBinding = binding ?: return
        val listMode = mode == AppSettings.SCHEDULE_LIST
        viewBinding.dayList.visibility = if (listMode) View.VISIBLE else View.GONE
        viewBinding.calendarScroll.visibility = if (listMode) View.GONE else View.VISIBLE
        viewBinding.btnDisplayMode.text =
            getString(
                if (listMode) R.string.sched_mode_list_short else R.string.sched_mode_calendar_short
            ) + " ▾"
    }

    private fun renderMonthLabel() {
        binding?.btnPickMonth?.text =
            getString(R.string.month_fmt, year, month) + " ▾"
    }

    // ---------------- 左右滑动翻月 ----------------

    /** 两种模式共用：左滑看下个月，右滑看上个月；纵向为主的手势交给列表自己滚，不抢 */
    private fun attachMonthSwipe(target: View) {
        val minDistance = 48 * resources.displayMetrics.density
        val detector = GestureDetector(requireContext(), object : GestureDetector.SimpleOnGestureListener() {
            override fun onDown(e: MotionEvent): Boolean = false
            override fun onFling(e1: MotionEvent?, e2: MotionEvent, velocityX: Float, velocityY: Float): Boolean {
                if (e1 == null) return false
                val dx = e2.x - e1.x
                val dy = e2.y - e1.y
                if (abs(dx) < minDistance) return false
                if (abs(dx) < abs(dy) * 1.5f) return false
                if (abs(velocityX) < 120f) return false
                shiftMonth(if (dx < 0) 1 else -1)
                return true
            }
        })
        target.setOnTouchListener { _, event -> detector.onTouchEvent(event) }
    }

    /** 翻到相邻月份：看的正是本月就选中今天，其它月份选 1 号；表头、整月网格与当天便签一起刷新 */
    private fun shiftMonth(delta: Int) {
        var newYear = year
        var newMonth = month + delta
        if (newMonth > 12) {
            newYear += 1
            newMonth = 1
        }
        if (newMonth < 1) {
            newYear -= 1
            newMonth = 12
        }
        year = newYear
        month = newMonth
        expandedKeys.clear()
        selectedDay = if (newYear == TimeUtil.todayYear() && newMonth == TimeUtil.todayMonth())
            TimeUtil.todayDay() else 1
        renderMonthLabel()
        load()
        binding?.dayList?.scrollToPosition(0)
        binding?.calendarScroll?.scrollTo(0, 0)
    }

    // ---------------- 数据 ----------------

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

        val offset = firstWeekdayOffset()
        val cells = ArrayList<CalCell>()
        repeat(offset) { cells.add(CalCell(0, "", 0)) }
        (1..days).forEach { day ->
            val key = TimeUtil.keyOf(year, month, day)
            cells.add(CalCell(day, key, counts[key] ?: 0))
        }
        calCells = cells
        calendarAdapter.submit(calCells, selectedDay, TimeUtil.todayKey())
        renderCalendar()
    }

    private fun submitCalendar() {
        calendarAdapter.submit(calCells, selectedDay, TimeUtil.todayKey())
        renderCalendar()
    }

    /** 1 号是周几 → 前面要空几格（周日=0，周一=1 … 周六=6） */
    private fun firstWeekdayOffset(): Int {
        val cal = Calendar.getInstance().apply {
            set(year, month - 1, 1, 0, 0, 0)
            set(Calendar.MILLISECOND, 0)
        }
        return cal.get(Calendar.DAY_OF_WEEK) - 1
    }

    /** 日历模式下，网格下方列出选中那天（没选就是 1 号 / 今天）的便签 */
    private fun renderCalendar() {
        val viewBinding = binding ?: return
        if (mode != AppSettings.SCHEDULE_CALENDAR) return

        if (selectedDay !in 1..TimeUtil.daysInMonth(year, month)) selectedDay = 1
        val key = TimeUtil.keyOf(year, month, selectedDay)
        viewBinding.calendarDayLabel.text = TimeUtil.fullDateLabel(key)

        val notes = Store.forDate(key)
        viewBinding.calendarNotes.removeAllViews()
        if (notes.isEmpty()) {
            val empty = TextView(requireContext()).apply {
                text = getString(R.string.date_empty_hint)
                setTextColor(ContextCompat.getColor(requireContext(), R.color.text_secondary))
                textSize = 12f
                setPadding(dp(8), dp(10), dp(8), dp(10))
            }
            viewBinding.calendarNotes.addView(empty)
            return
        }
        val inflater = layoutInflater
        notes.forEach { note ->
            val item = ItemNoteBinding.inflate(inflater, viewBinding.calendarNotes, false)
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
            item.root.setOnClickListener { openDetail(note) }
            viewBinding.calendarNotes.addView(item.root)
        }
    }

    // ---------------- 垂直模式 ----------------

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

    private fun dp(value: Int): Int = (value * resources.displayMetrics.density).toInt()
}
