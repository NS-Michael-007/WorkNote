package com.workspace.worknote.ui

import android.os.Bundle
import android.view.View
import android.widget.Toast
import androidx.appcompat.app.AlertDialog
import androidx.recyclerview.widget.LinearLayoutManager
import com.workspace.worknote.R
import com.workspace.worknote.data.Note
import com.workspace.worknote.data.Store
import com.workspace.worknote.databinding.ActivityRecycleBinBinding
import com.workspace.worknote.logic.UiBus
import com.workspace.worknote.settings.ThemeHelper

/** 回收站：恢复到主界面，或彻底删掉 */
class RecycleBinActivity : BaseActivity() {

    private lateinit var binding: ActivityRecycleBinBinding
    private val adapter = NoteAdapter { note -> showOptions(note) }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        binding = ActivityRecycleBinBinding.inflate(layoutInflater)
        setContentView(binding.root)

        binding.binList.layoutManager = LinearLayoutManager(this)
        binding.binList.adapter = adapter
        binding.btnBack.setOnClickListener { finish() }
        ThemeHelper.applyPageBackground(binding.root)
    }

    override fun onResume() {
        super.onResume()
        load()
    }

    private fun load() {
        val list = Store.deleted()
        adapter.submit(list)
        binding.emptyView.visibility = if (list.isEmpty()) View.VISIBLE else View.GONE
    }

    private fun showOptions(note: Note) {
        AlertDialog.Builder(this)
            .setTitle(note.title)
            .setItems(
                arrayOf(getString(R.string.bin_restore), getString(R.string.bin_purge))
            ) { _, which ->
                if (which == 0) {
                    Store.restore(note.id)
                    UiBus.notify(this)
                    Toast.makeText(this, R.string.bin_restored, Toast.LENGTH_SHORT).show()
                    load()
                } else {
                    confirmHardDelete(note)
                }
            }
            .show()
    }

    private fun confirmHardDelete(note: Note) {
        AlertDialog.Builder(this)
            .setTitle(R.string.bin_purge_title)
            .setMessage(R.string.bin_purge_msg)
            .setPositiveButton(R.string.bin_purge) { _, _ ->
                Store.hardDelete(note.id)
                UiBus.notify(this)
                Toast.makeText(this, R.string.bin_purged, Toast.LENGTH_SHORT).show()
                load()
            }
            .setNegativeButton(android.R.string.cancel, null)
            .show()
    }
}
