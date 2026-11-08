package com.workspace.worknote.data

import android.content.ContentValues
import android.content.Context
import android.database.Cursor
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper
import org.json.JSONArray
import org.json.JSONObject

/** 本地数据库（SQLite 直连，等效于 Room，且不依赖注解处理器） */
class NoteDb(context: Context) :
    SQLiteOpenHelper(context.applicationContext, DB_NAME, null, DB_VERSION) {

    override fun onCreate(db: SQLiteDatabase) {
        db.execSQL(
            "CREATE TABLE $TABLE (" +
                "_id INTEGER PRIMARY KEY AUTOINCREMENT," +
                "title TEXT NOT NULL," +
                "remark TEXT," +
                "date_key TEXT," +
                "remind_at INTEGER NOT NULL DEFAULT 0," +
                "loop_type TEXT," +
                "repeat_enabled INTEGER NOT NULL DEFAULT 0," +
                "repeat_minutes INTEGER NOT NULL DEFAULT 15," +
                "status TEXT," +
                "actions TEXT," +
                "created_at INTEGER," +
                "updated_at INTEGER," +
                "remind_count INTEGER NOT NULL DEFAULT 0)"
        )
    }

    override fun onUpgrade(db: SQLiteDatabase, oldVersion: Int, newVersion: Int) {
        db.execSQL("DROP TABLE IF EXISTS $TABLE")
        onCreate(db)
    }

    companion object {
        const val DB_NAME = "worknote.db"
        const val DB_VERSION = 1
        const val TABLE = "notes"
    }
}

/** 便签读写 */
class NoteDao(context: Context) {

    private val helper = NoteDb(context)

    fun insert(note: Note): Long {
        val values = toValues(note)
        val id = helper.writableDatabase.insert(NoteDb.TABLE, null, values)
        note.id = id
        return id
    }

    fun insertAll(notes: List<Note>) {
        val db = helper.writableDatabase
        db.beginTransaction()
        try {
            notes.forEach { db.insert(NoteDb.TABLE, null, toValues(it)) }
            db.setTransactionSuccessful()
        } finally {
            db.endTransaction()
        }
    }

    fun update(note: Note) {
        helper.writableDatabase.update(
            NoteDb.TABLE, toValues(note), "_id=?", arrayOf(note.id.toString())
        )
    }

    fun get(id: Long): Note? = query("_id=?", arrayOf(id.toString())).firstOrNull()

    fun all(): List<Note> = query(null, null)

    fun visible(): List<Note> = query("status<>?", arrayOf(Status.DELETED))

    fun deleted(): List<Note> = query("status=?", arrayOf(Status.DELETED))

    fun forDate(dateKey: String): List<Note> =
        query("date_key=? AND status<>?", arrayOf(dateKey, Status.DELETED))

    /** 每个日期上未处理（待提醒/待处理/已延后）的条数 */
    fun activeCountsByDate(): Map<String, Int> {
        val map = HashMap<String, Int>()
        val sql = "SELECT date_key, COUNT(*) FROM ${NoteDb.TABLE} " +
            "WHERE status IN (?,?,?) AND date_key<>'' GROUP BY date_key"
        val cursor = helper.readableDatabase.rawQuery(
            sql, arrayOf(Status.PENDING, Status.READY, Status.POSTPONED)
        )
        cursor.use {
            while (it.moveToNext()) map[it.getString(0)] = it.getInt(1)
        }
        return map
    }

    fun activeTotal(): Int {
        val sql = "SELECT COUNT(*) FROM ${NoteDb.TABLE} WHERE status IN (?,?,?)"
        val cursor = helper.readableDatabase.rawQuery(
            sql, arrayOf(Status.PENDING, Status.READY, Status.POSTPONED)
        )
        cursor.use { return if (it.moveToNext()) it.getInt(0) else 0 }
    }

    fun hardDelete(id: Long) {
        helper.writableDatabase.delete(NoteDb.TABLE, "_id=?", arrayOf(id.toString()))
    }

    fun clearAll() {
        helper.writableDatabase.delete(NoteDb.TABLE, null, null)
    }

    private fun query(where: String?, args: Array<String>?): List<Note> {
        val list = ArrayList<Note>()
        helper.readableDatabase.query(
            NoteDb.TABLE, null, where, args, null, null, "created_at DESC"
        ).use { cursor ->
            while (cursor.moveToNext()) list.add(fromCursor(cursor))
        }
        return list
    }

    private fun fromCursor(c: Cursor): Note = Note(
        id = c.getLong(c.getColumnIndexOrThrow("_id")),
        title = c.getString(c.getColumnIndexOrThrow("title")) ?: "",
        remark = c.getString(c.getColumnIndexOrThrow("remark")) ?: "",
        dateKey = c.getString(c.getColumnIndexOrThrow("date_key")) ?: "",
        remindAt = c.getLong(c.getColumnIndexOrThrow("remind_at")),
        loopType = c.getString(c.getColumnIndexOrThrow("loop_type")) ?: LoopType.NONE,
        repeatEnabled = c.getInt(c.getColumnIndexOrThrow("repeat_enabled")) == 1,
        repeatMinutes = c.getInt(c.getColumnIndexOrThrow("repeat_minutes")),
        status = c.getString(c.getColumnIndexOrThrow("status")) ?: Status.PENDING,
        actions = parseActions(c.getString(c.getColumnIndexOrThrow("actions"))),
        createdAt = c.getLong(c.getColumnIndexOrThrow("created_at")),
        updatedAt = c.getLong(c.getColumnIndexOrThrow("updated_at")),
        remindCount = c.getInt(c.getColumnIndexOrThrow("remind_count"))
    )

    private fun toValues(note: Note): ContentValues = ContentValues().apply {
        put("title", note.title)
        put("remark", note.remark)
        put("date_key", note.dateKey)
        put("remind_at", note.remindAt)
        put("loop_type", note.loopType)
        put("repeat_enabled", if (note.repeatEnabled) 1 else 0)
        put("repeat_minutes", note.repeatMinutes)
        put("status", note.status)
        put("actions", actionsToJson(note.actions))
        put("created_at", note.createdAt)
        put("updated_at", note.updatedAt)
        put("remind_count", note.remindCount)
    }

    private fun actionsToJson(actions: List<NoteAction>): String {
        val array = JSONArray()
        actions.forEach { action ->
            array.put(JSONObject().apply {
                put("text", action.text)
                put("type", action.type)
            })
        }
        return array.toString()
    }

    private fun parseActions(raw: String?): List<NoteAction> {
        if (raw.isNullOrEmpty()) return emptyList()
        val list = ArrayList<NoteAction>()
        try {
            val array = JSONArray(raw)
            for (i in 0 until array.length()) {
                val obj = array.optJSONObject(i) ?: continue
                list.add(NoteAction(obj.optString("text"), obj.optString("type", ActionType.DONE)))
            }
        } catch (ignored: Exception) {
        }
        return list
    }
}
