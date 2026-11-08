package com.workspace.worknote.ui

import android.content.Context
import android.view.Gravity
import android.widget.LinearLayout
import android.widget.NumberPicker
import android.widget.TextView
import androidx.appcompat.app.AlertDialog
import androidx.core.content.ContextCompat
import com.workspace.worknote.R
import com.workspace.worknote.util.TimeUtil

/**
 * 日程页顶部的年月选择：一次把年份和月份都选好，不用点箭头一月一月翻。
 * 年份用滚轮，月份用十二宫格，另有「回到本月」。
 */
object MonthPicker {

    fun show(
        context: Context,
        year: Int,
        month: Int,
        onPicked: (year: Int, month: Int) -> Unit
    ) {
        val density = context.resources.displayMetrics.density
        fun dp(value: Int): Int = (value * density).toInt()

        var pickedYear = year
        var pickedMonth = month

        val container = LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(20), dp(12), dp(20), dp(4))
        }

        val yearLabel = TextView(context).apply {
            text = context.getString(R.string.pick_year)
            setTextColor(ContextCompat.getColor(context, R.color.text_secondary))
            textSize = 12f
        }

        val yearPicker = NumberPicker(context).apply {
            minValue = 2000
            maxValue = 2100
            value = year
            wrapSelectorWheel = false
            setOnValueChangedListener { _, _, newValue -> pickedYear = newValue }
        }

        val grid = LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply { topMargin = dp(12) }
        }

        val chips = ArrayList<TextView>()
        fun paintSelection() {
            chips.forEachIndexed { index, chip ->
                val selected = index + 1 == pickedMonth
                chip.background = ContextCompat.getDrawable(
                    context,
                    if (selected) R.drawable.bg_button_primary else R.drawable.bg_field
                )
                chip.setTextColor(
                    ContextCompat.getColor(
                        context,
                        if (selected) android.R.color.white else R.color.text_primary
                    )
                )
            }
        }

        for (row in 0 until 4) {
            val rowView = LinearLayout(context).apply {
                orientation = LinearLayout.HORIZONTAL
                layoutParams = LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT
                ).apply { if (row > 0) topMargin = dp(8) }
            }
            for (column in 0 until 3) {
                val index = row * 3 + column
                val label = (index + 1).toString() + context.getString(R.string.month_unit_suffix)
                val chip = TextView(context).apply {
                    text = label
                    gravity = Gravity.CENTER
                    textSize = 14f
                    setPadding(0, dp(10), 0, dp(10))
                    isClickable = true
                    isFocusable = true
                    layoutParams = LinearLayout.LayoutParams(
                        0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f
                    ).apply { if (column > 0) marginStart = dp(8) }
                    setOnClickListener {
                        pickedMonth = index + 1
                        paintSelection()
                    }
                }
                rowView.addView(chip)
                chips.add(chip)
            }
            grid.addView(rowView)
        }
        paintSelection()

        container.addView(yearLabel)
        container.addView(yearPicker)
        container.addView(grid)

        AlertDialog.Builder(context)
            .setTitle(R.string.pick_month)
            .setView(container)
            .setPositiveButton(android.R.string.ok) { _, _ ->
                onPicked(pickedYear, pickedMonth)
            }
            .setNeutralButton(R.string.pick_today) { _, _ ->
                onPicked(TimeUtil.todayYear(), TimeUtil.todayMonth())
            }
            .setNegativeButton(android.R.string.cancel, null)
            .show()
    }
}
