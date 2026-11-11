package com.workspace.worknote.logic

import java.util.regex.Pattern

/**
 * 从截图识别出来的纯文本里，抽出「这是一趟什么行程」。
 *
 * 只做规则抽取，不做猜事实：抓不到日期或时间就留空，交给用户在编辑页自己补。
 * 支持三类常见截图：
 *  - 机票 / 航班行程（航班号 + 出发到达 + 起飞时间）
 *  - 火车票（车次 + 出发到达站 + 发车时间）
 *  - 接送机 / 会议通知那种「某月某日某点、去哪里、接谁」的行程截图
 */
object TripParser {

    data class Guess(
        val title: String,
        val detail: String,
        val year: Int?,
        val month: Int?,
        val day: Int?,
        val hour: Int?,
        val minute: Int?,
        val kind: String
    )

    const val KIND_FLIGHT = "flight"
    const val KIND_TRAIN = "train"
    const val KIND_OTHER = "other"

    private val FLIGHT = Pattern.compile("(?<![A-Za-z0-9])([A-Za-z]{2}\\s?\\d{3,4})(?![0-9])")
    private val TRAIN = Pattern.compile("([GDCKTZ]\\s?\\d{1,4})(?![0-9])")
    private val DATE_FULL = Pattern.compile("(\\d{4})\\s*年\\s*(\\d{1,2})\\s*月\\s*(\\d{1,2})\\s*日")
    private val DATE_MONTH_DAY = Pattern.compile("(\\d{1,2})\\s*月\\s*(\\d{1,2})\\s*日")
    private val DATE_DASH = Pattern.compile("(\\d{4})[-/](\\d{1,2})[-/](\\d{1,2})")
    private val TIME = Pattern.compile("(\\d{1,2})[:：](\\d{2})")
    private val STATION = Pattern.compile("([\\u4e00-\\u9fa5]{2,8}(?:站|机场|航站楼))")
    private val ROUTE = Pattern.compile("([\\u4e00-\\u9fa5]{2,10})\\s*(?:→|->|—|至|到|飞往)\\s*([\\u4e00-\\u9fa5]{2,10})")
    private val TIME_KEYWORD = Pattern.compile("起飞|出发|发车|始发|登机|开车|接机|送机|到达|抵达")

    fun parse(raw: String): Guess {
        val lines = raw.split('\n', '\r').map { it.trim() }.filter { it.isNotEmpty() }
        val text = lines.joinToString(" ")

        val flight = firstGroup(FLIGHT, text)
        val train = if (flight == null) firstGroup(TRAIN, text) else null
        val route = routeOf(text)
        val stations = stationsOf(text)

        var year: Int? = null
        var month: Int? = null
        var day: Int? = null
        DATE_FULL.matcher(text).let { m ->
            if (m.find()) {
                year = m.group(1)?.toIntOrNull()
                month = m.group(2)?.toIntOrNull()
                day = m.group(3)?.toIntOrNull()
            }
        }
        if (day == null) {
            DATE_DASH.matcher(text).let { m ->
                if (m.find()) {
                    year = m.group(1)?.toIntOrNull()
                    month = m.group(2)?.toIntOrNull()
                    day = m.group(3)?.toIntOrNull()
                }
            }
        }
        if (day == null) {
            DATE_MONTH_DAY.matcher(text).let { m ->
                if (m.find()) {
                    month = m.group(1)?.toIntOrNull()
                    day = m.group(2)?.toIntOrNull()
                }
            }
        }

        val time = pickTime(lines, text)

        val title: String
        val kind: String
        when {
            flight != null -> {
                kind = KIND_FLIGHT
                val code = flight.replace(" ", "").uppercase()
                val where = when {
                    route != null -> " ${route.first}→${route.second}"
                    stations.size >= 2 -> " ${stations[0].removeSuffix("站")}→${stations[1].removeSuffix("站")}"
                    else -> ""
                }
                title = "航班 $code$where"
            }
            train != null -> {
                kind = KIND_TRAIN
                val code = train.replace(" ", "").uppercase()
                val where = when {
                    stations.size >= 2 -> " ${stations[0].removeSuffix("站")}→${stations[1].removeSuffix("站")}"
                    route != null -> " ${route.first}→${route.second}"
                    else -> ""
                }
                title = "车次 $code$where"
            }
            else -> {
                kind = KIND_OTHER
                val first = lines.firstOrNull().orEmpty()
                title = first.take(28).ifBlank { "行程" }
            }
        }

        val detail = buildDetail(lines, flight, train, stations, route)
        return Guess(title, detail, year, month, day, time?.first, time?.second, kind)
    }

    private fun pickTime(lines: List<String>, text: String): Pair<Int, Int>? {
        // 优先取带「起飞 / 发车 / 出发 / 接机」的那一行，其次取第一处时间
        lines.firstOrNull { TIME_KEYWORD.matcher(it).find() && TIME.matcher(it).find() }?.let { line ->
            val m = TIME.matcher(line)
            if (m.find()) {
                val h = m.group(1)?.toIntOrNull()
                val min = m.group(2)?.toIntOrNull()
                if (h != null && min != null && h in 0..23 && min in 0..59) return h to min
            }
        }
        val m = TIME.matcher(text)
        while (m.find()) {
            val h = m.group(1)?.toIntOrNull()
            val min = m.group(2)?.toIntOrNull()
            if (h != null && min != null && h in 0..23 && min in 0..59) return h to min
        }
        return null
    }

    private fun buildDetail(
        lines: List<String>,
        flight: String?,
        train: String?,
        stations: List<String>,
        route: Pair<String, String>?
    ): String {
        val parts = ArrayList<String>()
        flight?.let { parts.add("航班：" + it.replace(" ", "").uppercase()) }
        train?.let { parts.add("车次：" + it.replace(" ", "").uppercase()) }
        route?.let { parts.add("路线：" + it.first + " → " + it.second) }
        if (stations.isNotEmpty()) parts.add("地点：" + stations.joinToString("、"))
        val body = lines.take(6).joinToString("\n")
        if (body.isNotEmpty()) parts.add("截图原文：\n" + body)
        return parts.joinToString("\n")
    }

    private fun firstGroup(pattern: Pattern, text: String): String? {
        val m = pattern.matcher(text)
        return if (m.find()) m.group(1) else null
    }

    private fun routeOf(text: String): Pair<String, String>? {
        val m = ROUTE.matcher(text)
        return if (m.find()) {
            val a = m.group(1)
            val b = m.group(2)
            if (a != null && b != null) a to b else null
        } else null
    }

    private fun stationsOf(text: String): List<String> {
        val m = STATION.matcher(text)
        val list = ArrayList<String>()
        while (m.find() && list.size < 4) {
            m.group(1)?.let { list.add(it) }
        }
        return list
    }
}
