package com.workspace.worknote.settings

import android.content.Context
import android.content.SharedPreferences
import java.util.Locale

/** 全部可调设置的唯一入口，值存 SharedPreferences，进程内即时可读 */
object AppSettings {

    private const val FILE = "worknote_settings"

    // ---- 深色模式 ----
    const val DARK_FOLLOW_SYSTEM = 0
    const val DARK_LIGHT = 1
    const val DARK_NIGHT = 2

    // ---- 语言 ----
    const val LANG_SYSTEM = "system"
    const val LANG_ZH = "zh"
    const val LANG_ZH_HANT = "zh-Hant"
    const val LANG_EN = "en"

    private fun p(context: Context): SharedPreferences =
        context.applicationContext.getSharedPreferences(FILE, Context.MODE_PRIVATE)

    private fun getInt(context: Context, key: String, def: Int): Int = p(context).getInt(key, def)
    private fun setInt(context: Context, key: String, value: Int) {
        p(context).edit().putInt(key, value).apply()
    }

    private fun getBool(context: Context, key: String, def: Boolean): Boolean =
        p(context).getBoolean(key, def)

    private fun setBool(context: Context, key: String, value: Boolean) {
        p(context).edit().putBoolean(key, value).apply()
    }

    // ---------------- 深色模式 ----------------
    fun darkMode(context: Context): Int = getInt(context, "dark_mode", DARK_FOLLOW_SYSTEM)
    fun setDarkMode(context: Context, mode: Int) = setInt(context, "dark_mode", mode)

    // ---------------- 字号 1~10 ----------------
    fun fontLevel(context: Context): Int = getInt(context, "font_level", 4).coerceIn(1, 10)
    fun setFontLevel(context: Context, level: Int) = setInt(context, "font_level", level.coerceIn(1, 10))

    /** 1 档 0.85 → 4 档 1.00（默认）→ 10 档 1.30 */
    fun fontScale(context: Context): Float = 0.80f + fontLevel(context) * 0.05f

    // ---------------- 语言 ----------------
    fun language(context: Context): String = p(context).getString("language", LANG_SYSTEM) ?: LANG_SYSTEM
    fun setLanguage(context: Context, lang: String) {
        p(context).edit().putString("language", lang).apply()
    }

    /** 返回 null 表示跟随系统 */
    fun localeFor(context: Context): Locale? = when (language(context)) {
        LANG_ZH -> Locale.SIMPLIFIED_CHINESE
        // zh-TW 的脚本是 Hant，会命中 values-b+zh+Hant；港澳的 zh-HK 也落到同一套资源
        LANG_ZH_HANT -> Locale.TRADITIONAL_CHINESE
        LANG_EN -> Locale.ENGLISH
        else -> null
    }

    // ---------------- 背景图 ----------------
    fun backgroundPath(context: Context): String? = p(context).getString("bg_path", null)
    fun setBackgroundPath(context: Context, path: String?) {
        p(context).edit().putString("bg_path", path).apply()
    }

    // ---------------- 通知表现 ----------------
    fun notifySound(context: Context): Boolean = getBool(context, "notify_sound", true)
    fun setNotifySound(context: Context, on: Boolean) = setBool(context, "notify_sound", on)

    fun notifyVibrate(context: Context): Boolean = getBool(context, "notify_vibrate", true)
    fun setNotifyVibrate(context: Context, on: Boolean) = setBool(context, "notify_vibrate", on)

    fun notifyScreenOn(context: Context): Boolean = getBool(context, "notify_screen_on", true)
    fun setNotifyScreenOn(context: Context, on: Boolean) = setBool(context, "notify_screen_on", on)

    // ---------------- 提醒铃声 ----------------
    /** 自定义铃声的私有副本绝对路径；null 表示用系统默认提醒音 */
    fun ringtonePath(context: Context): String? = p(context).getString("ringtone_path", null)
    fun setRingtonePath(context: Context, path: String?) {
        p(context).edit().putString("ringtone_path", path).apply()
    }

    /** 用户选的那首歌的原始文件名，只用于界面显示 */
    fun ringtoneLabel(context: Context): String? = p(context).getString("ringtone_label", null)
    fun setRingtoneLabel(context: Context, label: String?) {
        p(context).edit().putString("ringtone_label", label).apply()
    }

    // ---------------- 闹钟与提醒默认值 ----------------
    fun defaultDelayMinutes(context: Context): Int = getInt(context, "delay_minutes", 30)
    fun setDefaultDelayMinutes(context: Context, minutes: Int) = setInt(context, "delay_minutes", minutes)

    fun defaultRepeatMinutes(context: Context): Int = getInt(context, "repeat_minutes", 15)
    fun setDefaultRepeatMinutes(context: Context, minutes: Int) = setInt(context, "repeat_minutes", minutes)

    fun useExactAlarm(context: Context): Boolean = getBool(context, "exact_alarm", true)
    fun setUseExactAlarm(context: Context, on: Boolean) = setBool(context, "exact_alarm", on)

    // ---------------- 设置页分组折叠 ----------------
    /** 记哪些分组是展开的；不在集合里就是收起（默认全部收起，点标题才展开） */
    fun expandedSections(context: Context): Set<String> =
        p(context).getStringSet("expanded_sections", emptySet()) ?: emptySet()

    fun setExpandedSections(context: Context, ids: Set<String>) {
        p(context).edit().putStringSet("expanded_sections", ids).apply()
    }

    // ---------------- 日程显示模式 ----------------
    const val SCHEDULE_LIST = "list"
    const val SCHEDULE_CALENDAR = "calendar"

    fun scheduleMode(context: Context): String =
        p(context).getString("schedule_mode", SCHEDULE_LIST) ?: SCHEDULE_LIST

    fun setScheduleMode(context: Context, mode: String) {
        p(context).edit().putString("schedule_mode", mode).apply()
    }

    // ---------------- 功能说明页的内容播报 ----------------
    fun helpTts(context: Context): Boolean = getBool(context, "help_tts", false)
    fun setHelpTts(context: Context, on: Boolean) = setBool(context, "help_tts", on)
}
