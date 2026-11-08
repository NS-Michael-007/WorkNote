package com.workspace.worknote.data

import android.content.ContentValues
import android.content.Context
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import com.workspace.worknote.R
import com.workspace.worknote.logic.ReminderScheduler
import com.workspace.worknote.util.TimeUtil
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * 备份导出 / 恢复。
 * 只备份便签数据本身：卸装 App 不会删掉下载目录里的文件，所以换机靠它。
 * 定时提醒属于系统调度记录，不会跟着文件走，导入后必须重新排闹钟。
 */
object BackupManager {

    private const val VERSION = 1
    private const val DIR_NAME = "工作便签提醒"
    private val stampFmt = SimpleDateFormat("yyyyMMdd_HHmm", Locale.CHINA)

    /** 导出到系统下载目录，返回给人看的保存位置 */
    fun export(context: Context): String {
        val root = JSONObject()
        root.put("app", "工作便签提醒")
        root.put("version", VERSION)
        root.put("exportedAt", TimeUtil.now())
        val notes = JSONArray()
        Store.all().forEach { notes.put(toJson(it)) }
        root.put("notes", notes)
        val text = root.toString(2)

        val fileName = "WorkNote_" + stampFmt.format(Date()) + ".taskbak"

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val values = ContentValues().apply {
                put(MediaStore.MediaColumns.DISPLAY_NAME, fileName)
                put(MediaStore.MediaColumns.MIME_TYPE, "application/json")
                put(MediaStore.MediaColumns.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS + "/" + DIR_NAME)
            }
            val uri = context.contentResolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)
                ?: throw IllegalStateException(context.getString(R.string.err_backup_no_target))
            context.contentResolver.openOutputStream(uri)?.use {
                it.write(text.toByteArray(Charsets.UTF_8))
            } ?: throw IllegalStateException(context.getString(R.string.err_backup_write))
            return "下载/$DIR_NAME/$fileName"
        }

        @Suppress("DEPRECATION")
        val dir = File(Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS), DIR_NAME)
        if (!dir.exists() && !dir.mkdirs()) throw IllegalStateException(context.getString(R.string.err_backup_no_dir))
        val file = File(dir, fileName)
        file.writeText(text, Charsets.UTF_8)
        return file.absolutePath
    }

    /** 从备份文件恢复，返回导入条数 */
    fun importFrom(context: Context, uri: Uri): Int {
        val text = context.contentResolver.openInputStream(uri)?.use {
            it.readBytes().toString(Charsets.UTF_8)
        } ?: throw IllegalStateException(context.getString(R.string.err_backup_read))

        val root = JSONObject(text)
        val array = root.optJSONArray("notes")
            ?: throw IllegalStateException(context.getString(R.string.err_backup_not_ours))

        val notes = ArrayList<Note>()
        for (i in 0 until array.length()) {
            val obj = array.optJSONObject(i) ?: continue
            notes.add(fromJson(context, obj))
        }
        if (notes.isEmpty()) throw IllegalStateException(context.getString(R.string.err_backup_empty))

        Store.replaceAll(notes)
        ReminderScheduler.rescheduleAll(context)
        return notes.size
    }

    private fun toJson(note: Note): JSONObject = JSONObject().apply {
        put("title", note.title)
        put("remark", note.remark)
        put("dateKey", note.dateKey)
        put("remindAt", note.remindAt)
        put("loopType", note.loopType)
        put("repeatEnabled", note.repeatEnabled)
        put("repeatMinutes", note.repeatMinutes)
        put("status", note.status)
        put("createdAt", note.createdAt)
        put("remindCount", note.remindCount)
        val actions = JSONArray()
        note.actions.forEach { action ->
            actions.put(JSONObject().apply {
                put("text", action.text)
                put("type", action.type)
            })
        }
        put("actions", actions)
    }

    private fun fromJson(context: Context, obj: JSONObject): Note {
        val rawActions = obj.optJSONArray("actions")
        val actions = ArrayList<NoteAction>()
        if (rawActions != null) {
            for (i in 0 until rawActions.length()) {
                val item = rawActions.optJSONObject(i) ?: continue
                actions.add(
                    NoteAction(
                        text = item.optString("text"),
                        type = item.optString("type", ActionType.DONE)
                    )
                )
            }
        }
        val status = obj.optString("status", Status.PENDING)
        return Note(
            title = obj.optString("title", context.getString(R.string.unnamed_note)),
            remark = obj.optString("remark"),
            dateKey = obj.optString("dateKey", TimeUtil.todayKey()),
            remindAt = obj.optLong("remindAt", 0L),
            loopType = obj.optString("loopType", LoopType.NONE),
            repeatEnabled = obj.optBoolean("repeatEnabled", false),
            repeatMinutes = obj.optInt("repeatMinutes", 15),
            status = if (status == Status.DELETED) Status.DELETED else Status.PENDING,
            actions = actions,
            createdAt = obj.optLong("createdAt", TimeUtil.now()),
            remindCount = 0
        )
    }
}
