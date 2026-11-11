package com.workspace.worknote.data

import android.content.Context

/** 全局数据入口，UI 与调度层都只认这个对象 */
object Store {

    private var dao: NoteDao? = null

    fun init(context: Context) {
        if (dao == null) dao = NoteDao(context.applicationContext)
    }

    private fun d(): NoteDao = dao ?: error("Store 尚未初始化")

    fun all(): List<Note> = d().all()

    fun visible(): List<Note> = d().visible()

    fun deleted(): List<Note> = d().deleted()

    fun get(id: Long): Note? = d().get(id)

    fun forDate(dateKey: String): List<Note> = d().forDate(dateKey)

    fun activeCounts(): Map<String, Int> = d().activeCountsByDate()

    fun activeTotal(): Int = d().activeTotal()

    fun insert(note: Note): Long = d().insert(note)

    fun update(note: Note) = d().update(note)

    fun moveToBin(id: Long) {
        val note = d().get(id) ?: return
        note.status = Status.DELETED
        note.updatedAt = System.currentTimeMillis()
        d().update(note)
    }

    fun restore(id: Long) {
        val note = d().get(id) ?: return
        note.status = Status.PENDING
        note.updatedAt = System.currentTimeMillis()
        d().update(note)
    }

    fun hardDelete(id: Long) = d().hardDelete(id)

    fun hardDeleteMany(ids: Collection<Long>) = d().hardDeleteMany(ids)

    fun hardDeleteAllDeleted(): Int = d().hardDeleteAllDeleted()

    fun replaceAll(notes: List<Note>) {
        d().clearAll()
        val now = System.currentTimeMillis()
        val fixed = notes.map { note ->
            note.copy(
                id = 0L,
                createdAt = if (note.createdAt > 0L) note.createdAt else now,
                updatedAt = now
            )
        }
        d().insertAll(fixed)
    }
}
