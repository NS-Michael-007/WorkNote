package com.workspace.worknote.util

import android.text.format.DateFormat
import com.workspace.worknote.R
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale

/** 时间显示与换算（全部按手机本地时区，显示文案跟随当前语言） */
object TimeUtil {

    private fun locale(): Locale =
        AppCtx.context.resources.configuration.locales[0] ?: Locale.getDefault()

    private fun s(id: Int, vararg args: Any): String =
        AppCtx.context.getString(id, *args)

    private val dateFmt = SimpleDateFormat("yyyy-MM-dd", Locale.US)
    private val shortDayFmt = SimpleDateFormat("MM-dd", Locale.US)

    private fun timeFmt() = SimpleDateFormat("HH:mm", locale())

    private fun monthDayFmt(): SimpleDateFormat {
        val pattern = DateFormat.getBestDateTimePattern(locale(), "MMMd")
        return SimpleDateFormat(pattern, locale())
    }

    fun now(): Long = System.currentTimeMillis()

    fun todayKey(): String = dateFmt.format(Date(now()))

    fun keyOf(ts: Long): String = dateFmt.format(Date(ts))

    fun keyOf(year: Int, month: Int, day: Int): String =
        String.format(Locale.US, "%04d-%02d-%02d", year, month, day)

    fun timeOf(ts: Long): String = timeFmt().format(Date(ts))

    fun monthDayOf(ts: Long): String = monthDayFmt().format(Date(ts))

    fun shortDayOf(ts: Long): String = shortDayFmt.format(Date(ts))

    fun monthLabel(year: Int, month: Int): String = s(R.string.month_fmt, year, month)

    /** 列表右侧显示的时间：今天 / 明天 / 带年份的具体日期（2026年11月8日 09:00） */
    fun friendly(ts: Long): String {
        if (ts <= 0L) return s(R.string.date_not_set)
        val key = keyOf(ts)
        if (key == todayKey()) {
            return s(R.string.date_prefix_fmt, s(R.string.day_today), timeOf(ts))
        }
        if (key == keyOf(now() + 86_400_000L)) {
            return s(R.string.date_prefix_fmt, s(R.string.day_tomorrow), timeOf(ts))
        }
        return s(R.string.date_prefix_fmt, fullDate(ts), timeOf(ts))
    }

    /** 只显示日期，用于详情页展示关联日期；非今天/明天时带年份（2026年11月8日） */
    fun dayLabel(key: String): String {
        val cal = parseKey(key) ?: return key
        if (key == todayKey()) return s(R.string.day_today)
        if (key == keyOf(now() + 86_400_000L)) return s(R.string.day_tomorrow)
        return fullDate(cal.timeInMillis)
    }

    private fun yearMonthDayFmt(): SimpleDateFormat {
        val pattern = DateFormat.getBestDateTimePattern(locale(), "yyyyMMMd")
        return SimpleDateFormat(pattern, locale())
    }

    /** 带年份的日期：2026年11月8日 */
    fun fullDate(ts: Long): String = yearMonthDayFmt().format(Date(ts))

    /** 带年份 + 周几的日期：2026年11月8日 周日 */
    fun fullDate(ts: Long, withWeekday: Boolean): String {
        val text = fullDate(ts)
        if (!withWeekday) return text
        val cal = partsOf(ts)
        return "$text ${weekdayLabel(cal.get(Calendar.YEAR), cal.get(Calendar.MONTH) + 1, cal.get(Calendar.DAY_OF_MONTH))}"
    }

    /** 关联日期那一行：当天会额外标「（今天）」 */
    fun fullDateLabel(key: String): String {
        val cal = parseKey(key) ?: return key
        val text = fullDate(cal.timeInMillis, withWeekday = true)
        return if (key == todayKey()) s(R.string.fmt_today_mark, text) else text
    }

    /** 提醒时间那一行：年月日 + 时分 */
    fun fullDateTime(ts: Long): String = "${fullDate(ts)} ${timeOf(ts)}"

    fun weekdayLabel(year: Int, month: Int, day: Int): String {
        val cal = Calendar.getInstance().apply {
            set(year, month - 1, day, 0, 0, 0)
            set(Calendar.MILLISECOND, 0)
        }
        val ids = intArrayOf(
            R.string.weekday_0, R.string.weekday_1, R.string.weekday_2, R.string.weekday_3,
            R.string.weekday_4, R.string.weekday_5, R.string.weekday_6
        )
        return s(ids[cal.get(Calendar.DAY_OF_WEEK) - 1])
    }

    fun daysInMonth(year: Int, month: Int): Int =
        Calendar.getInstance().apply {
            set(year, month - 1, 1, 0, 0, 0)
            set(Calendar.MILLISECOND, 0)
        }.getActualMaximum(Calendar.DAY_OF_MONTH)

    fun epochOf(year: Int, month: Int, day: Int, hour: Int, minute: Int): Long =
        Calendar.getInstance().apply {
            set(year, month - 1, day, hour, minute, 0)
            set(Calendar.MILLISECOND, 0)
        }.timeInMillis

    fun parseKey(key: String): Calendar? = try {
        val parsed = dateFmt.parse(key)
        if (parsed == null) null else Calendar.getInstance().apply { time = parsed }
    } catch (e: Exception) {
        null
    }

    fun partsOf(ts: Long): Calendar = Calendar.getInstance().apply { timeInMillis = ts }

    fun todayDay(): Int = partsOf(now()).get(Calendar.DAY_OF_MONTH)

    fun todayMonth(): Int = partsOf(now()).get(Calendar.MONTH) + 1

    fun todayYear(): Int = partsOf(now()).get(Calendar.YEAR)
}
