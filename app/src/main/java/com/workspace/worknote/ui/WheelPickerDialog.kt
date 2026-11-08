package com.workspace.worknote.ui

import android.app.AlertDialog
import android.content.Context
import android.view.View
import android.view.ViewGroup
import android.widget.LinearLayout
import android.widget.NumberPicker
import com.workspace.worknote.R
import com.workspace.worknote.util.TimeUtil
import java.util.Calendar

/**
 * 年 / 月 / 日（可选再加 时 / 分）滚轮选择框，底部三个按钮：取消 / 今天 / 确定。
 *
 * 用滚轮而不是日历盘，是为了让「年、月、日」三段都能直接翻，不用靠左右箭头一天一天挪。
 * 「今天」按钮对应需求里的「增加当天的」：点一下直接把日期落到今天，时间部分保持不变。
 *
 * 每个滚轮都用 [NumberPicker.setDisplayedValues] 直接贴好「2026年 / 11月 / 8日」这种完整文案，
 * 保证选中行和上下相邻行的写法一致（只用 formatter 时，中间选中行会漏掉单位）。
 */
object WheelPickerDialog {

    private const val YEAR_MIN = 1970
    private const val YEAR_MAX = 2100

    /** 只选日期：时分沿用 [initial] 的时分（[initial] <= 0 时用 09:00） */
    fun showDate(context: Context, initial: Long, onPick: (Long) -> Unit) {
        val base = TimeUtil.partsOf(if (initial > 0L) initial else defaultBase())
        val hour = base.get(Calendar.HOUR_OF_DAY)
        val minute = base.get(Calendar.MINUTE)
        show(context, base, withTime = false, titleRes = R.string.pick_date_title) { year, month, day, _, _ ->
            onPick(TimeUtil.epochOf(year, month, day, hour, minute))
        }
    }

    /** 选年月日 + 时分 */
    fun showDateTime(context: Context, initial: Long, onPick: (Long) -> Unit) {
        val base = TimeUtil.partsOf(if (initial > 0L) initial else defaultBase())
        show(context, base, withTime = true, titleRes = R.string.pick_time_title) { year, month, day, hour, minute ->
            onPick(TimeUtil.epochOf(year, month, day, hour, minute))
        }
    }

    private fun defaultBase(): Long {
        val cal = Calendar.getInstance()
        cal.set(Calendar.HOUR_OF_DAY, 9)
        cal.set(Calendar.MINUTE, 0)
        cal.set(Calendar.SECOND, 0)
        cal.set(Calendar.MILLISECOND, 0)
        return cal.timeInMillis
    }

    private fun yearLabels(context: Context): Array<String> {
        val list = ArrayList<String>(YEAR_MAX - YEAR_MIN + 1)
        for (y in YEAR_MIN..YEAR_MAX) list.add(context.getString(R.string.unit_year_fmt, y))
        return list.toTypedArray()
    }

    private fun monthLabels(context: Context): Array<String> {
        val list = ArrayList<String>(12)
        for (m in 1..12) list.add(context.getString(R.string.unit_month_fmt, m))
        return list.toTypedArray()
    }

    private fun dayLabels(context: Context, year: Int, month: Int): Array<String> {
        val max = TimeUtil.daysInMonth(year, month)
        val list = ArrayList<String>(max)
        for (d in 1..max) list.add(context.getString(R.string.unit_day_fmt, d))
        return list.toTypedArray()
    }

    private fun hourLabels(context: Context): Array<String> {
        val list = ArrayList<String>(24)
        for (h in 0..23) list.add(context.getString(R.string.unit_hour_fmt, h))
        return list.toTypedArray()
    }

    private fun minuteLabels(context: Context): Array<String> {
        val list = ArrayList<String>(60)
        for (m in 0..59) list.add(context.getString(R.string.unit_minute_fmt, m))
        return list.toTypedArray()
    }

    private fun show(
        context: Context,
        base: Calendar,
        withTime: Boolean,
        titleRes: Int,
        onPick: (year: Int, month: Int, day: Int, hour: Int, minute: Int) -> Unit
    ) {
        val density = context.resources.displayMetrics.density
        val pad = (18 * density).toInt()
        // 滚轮固定高度，避免外层按「可容纳全部条目」去量，把对话框撑成一整屏
        val wheelHeight = (180 * density).toInt()

        val yearPicker = NumberPicker(context).apply {
            descendantFocusability = NumberPicker.FOCUS_BLOCK_DESCENDANTS
            wrapSelectorWheel = false
            displayedValues = yearLabels(context)
            minValue = 0
            maxValue = displayedValues.size - 1
            value = (base.get(Calendar.YEAR) - YEAR_MIN).coerceIn(0, maxValue)
        }
        val monthPicker = NumberPicker(context).apply {
            descendantFocusability = NumberPicker.FOCUS_BLOCK_DESCENDANTS
            wrapSelectorWheel = false
            displayedValues = monthLabels(context)
            minValue = 0
            maxValue = 11
            value = base.get(Calendar.MONTH)
        }
        val dayPicker = NumberPicker(context).apply {
            descendantFocusability = NumberPicker.FOCUS_BLOCK_DESCENDANTS
            wrapSelectorWheel = false
        }
        val hourPicker = NumberPicker(context).apply {
            descendantFocusability = NumberPicker.FOCUS_BLOCK_DESCENDANTS
            wrapSelectorWheel = false
            displayedValues = hourLabels(context)
            minValue = 0
            maxValue = 23
            value = base.get(Calendar.HOUR_OF_DAY)
        }
        val minutePicker = NumberPicker(context).apply {
            descendantFocusability = NumberPicker.FOCUS_BLOCK_DESCENDANTS
            wrapSelectorWheel = false
            displayedValues = minuteLabels(context)
            minValue = 0
            maxValue = 59
            value = base.get(Calendar.MINUTE)
        }

        fun yearOf(): Int = YEAR_MIN + yearPicker.value
        fun monthOf(): Int = monthPicker.value + 1

        fun refreshDays(keepDay: Int) {
            val max = TimeUtil.daysInMonth(yearOf(), monthOf())
            val labels = dayLabels(context, yearOf(), monthOf())
            dayPicker.displayedValues = null
            dayPicker.minValue = 0
            dayPicker.maxValue = labels.size - 1
            dayPicker.displayedValues = labels
            dayPicker.value = (keepDay - 1).coerceIn(0, max - 1)
        }

        refreshDays(base.get(Calendar.DAY_OF_MONTH))
        yearPicker.setOnValueChangedListener { _, _, _ -> refreshDays(dayPicker.value + 1) }
        monthPicker.setOnValueChangedListener { _, _, _ -> refreshDays(dayPicker.value + 1) }

        fun pickedDay(): Int = dayPicker.value + 1

        val root = LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            layoutParams = ViewGroup.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT)
            setPadding(pad, pad / 2, pad, 0)
            addView(row(context, intArrayOf(3, 2, 2), wheelHeight, yearPicker, monthPicker, dayPicker))
            if (withTime) {
                // 时分那一行左边留出与「年」等宽的空位，让「时 / 分」正好落在「月 / 日」下面
                addView(row(context, intArrayOf(3, 2, 2), wheelHeight, View(context), hourPicker, minutePicker))
            }
        }

        AlertDialog.Builder(context)
            .setTitle(titleRes)
            .setView(root)
            .setNegativeButton(android.R.string.cancel, null)
            .setNeutralButton(R.string.day_today) { _, _ ->
                val today = TimeUtil.partsOf(TimeUtil.now())
                onPick(
                    today.get(Calendar.YEAR),
                    today.get(Calendar.MONTH) + 1,
                    today.get(Calendar.DAY_OF_MONTH),
                    hourPicker.value,
                    minutePicker.value
                )
            }
            .setPositiveButton(android.R.string.ok) { _, _ ->
                onPick(yearOf(), monthOf(), pickedDay(), hourPicker.value, minutePicker.value)
            }
            .show()
    }

    private fun row(context: Context, weights: IntArray, height: Int, vararg views: View): LinearLayout =
        LinearLayout(context).apply {
            orientation = LinearLayout.HORIZONTAL
            layoutParams = ViewGroup.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, height)
            views.forEachIndexed { index, view ->
                addView(view, LinearLayout.LayoutParams(0, height, weights[index].toFloat()))
            }
        }
}
