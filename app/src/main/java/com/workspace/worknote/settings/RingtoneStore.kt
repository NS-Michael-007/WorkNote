package com.workspace.worknote.settings

import android.content.Context
import android.net.Uri
import android.provider.OpenableColumns
import java.io.File

/**
 * 自定义提醒铃声：用户从「文件」或音乐 App 里选一首，复制进应用私有目录。
 * 只存私有副本，不依赖外部文件是否还在；换歌时删掉旧副本，避免占空间。
 */
object RingtoneStore {

    private const val DIR = "ringtone"
    private const val PREFIX = "alarm"

    private fun dir(context: Context): File = File(context.filesDir, DIR).apply { mkdirs() }

    /** 当前自定义铃声文件，没设置或文件丢了返回 null */
    fun current(context: Context): File? {
        val path = AppSettings.ringtonePath(context) ?: return null
        val f = File(path)
        return if (f.exists() && f.length() > 0) f else null
    }

    /** 复制选中的音频进私有目录，返回落盘后的文件；失败抛异常给界面提示 */
    fun import(context: Context, uri: Uri): File {
        val name = displayName(context, uri)
        val ext = pickExtension(name)
        val target = File(dir(context), "$PREFIX.$ext")

        // 先清掉上一次的副本（可能扩展名不同）
        dir(context).listFiles()?.forEach { old ->
            if (old.name.startsWith(PREFIX)) runCatching { old.delete() }
        }

        context.contentResolver.openInputStream(uri).use { input ->
            if (input == null) throw IllegalStateException(context.getString(com.workspace.worknote.R.string.ringtone_unreadable))
            target.outputStream().use { out -> input.copyTo(out) }
        }

        if (target.length() <= 0) {
            runCatching { target.delete() }
            throw IllegalStateException(context.getString(com.workspace.worknote.R.string.ringtone_unreadable))
        }

        AppSettings.setRingtonePath(context, target.absolutePath)
        AppSettings.setRingtoneLabel(context, name)
        return target
    }

    fun reset(context: Context) {
        dir(context).listFiles()?.forEach { old -> runCatching { old.delete() } }
        AppSettings.setRingtonePath(context, null)
        AppSettings.setRingtoneLabel(context, null)
    }

    fun sizeBytes(context: Context): Long = current(context)?.length() ?: 0L

    private fun displayName(context: Context, uri: Uri): String {
        runCatching {
            context.contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use { c ->
                if (c.moveToFirst()) {
                    val idx = c.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                    if (idx >= 0) {
                        val v = c.getString(idx)
                        if (!v.isNullOrBlank()) return v
                    }
                }
            }
        }
        return uri.lastPathSegment?.substringAfterLast('/')?.takeIf { it.isNotBlank() } ?: "ringtone"
    }

    /** 按扩展名决定落盘后缀；认不出来的统一按 mp3 存，MediaPlayer 靠内容嗅探也能播 */
    private fun pickExtension(name: String): String {
        val ext = name.substringAfterLast('.', "").lowercase()
        return when (ext) {
            "mp3", "m4a", "aac", "wav", "ogg", "opus", "flac", "mid", "amr" -> ext
            else -> "mp3"
        }
    }
}
