package com.workspace.worknote.ui

import android.os.Bundle
import android.view.View
import android.widget.Toast
import androidx.appcompat.app.AlertDialog
import androidx.core.content.ContextCompat
import androidx.recyclerview.widget.LinearLayoutManager
import com.workspace.worknote.R
import com.workspace.worknote.data.Note
import com.workspace.worknote.data.Store
import com.workspace.worknote.databinding.ActivityRecycleBinBinding
import com.workspace.worknote.logic.UiBus
import com.workspace.worknote.settings.ThemeHelper

/**
 * 回收站：默认逐条处理（点开一条 → 恢复到主界面 / 彻底删除），
 * 右上角「多选」进入多选后可以勾选若干条批量删除，也可以一次全部删除。
 */
class RecycleBinActivity : BaseActivity() {

    private lateinit var binding: ActivityRecycleBinBinding
    private val adapter = BinAdapter(
        onRowClick = { note -> showOptions(note) },
        onSelectionChanged = { updateHeaderAndBar() }
    )

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        binding = ActivityRecycleBinBinding.inflate(layoutInflater)
        setContentView(binding.root)

        binding.binList.layoutManager = LinearLayoutManager(this)
        binding.binList.adapter = adapter
        binding.btnBack.setOnClickListener { finish() }
        binding.btnSelect.setOnClickListener {
            if (adapter.isSelecting()) adapter.setSelecting(false)
            else adapter.setSelecting(true)
        }
        binding.btnDeleteAll.setOnClickListener { confirmPurgeAll() }
        binding.btnSelectAll.setOnClickListener {
            adapter.selectAll(!adapter.allSelected())
        }
        binding.btnDeleteSelected.setOnClickListener { confirmPurgeSelected() }
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
        if (list.isEmpty() && adapter.isSelecting()) adapter.setSelecting(false)
        updateHeaderAndBar()
    }

    /** 顶部两个按钮：列表有内容才出现；多选时「多选」变成「退出多选」，「全部删除」先收起 */
    private fun updateHeaderAndBar() {
        val hasItems = adapter.itemCount > 0
        val selecting = adapter.isSelecting()

        binding.btnSelect.visibility = if (hasItems) View.VISIBLE else View.GONE
        binding.btnSelect.text =
            getString(if (selecting) R.string.bin_multi_exit else R.string.bin_multi_select)
        binding.btnDeleteAll.visibility =
            if (hasItems && !selecting) View.VISIBLE else View.GONE

        binding.selectionBar.visibility = if (selecting) View.VISIBLE else View.GONE
        if (!selecting) return

        val count = adapter.selectedCount()
        binding.btnSelectAll.text =
            getString(if (adapter.allSelected()) R.string.bin_select_none else R.string.bin_select_all)
        binding.txtSelected.text = getString(R.string.bin_selected_fmt, count)
        binding.btnDeleteSelected.text = getString(R.string.bin_delete_selected_fmt, count)
        binding.btnDeleteSelected.isEnabled = count > 0
        binding.btnDeleteSelected.alpha = if (count > 0) 1f else 0.5f
        binding.btnDeleteSelected.setTextColor(
            if (count > 0) ContextCompat.getColor(this, android.R.color.white)
            else ContextCompat.getColor(this, R.color.disabled_text)
        )
    }

    // ---------------- 保留原有的逐条处理 ----------------

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

    // ---------------- 多选删除 ----------------

    private fun confirmPurgeSelected() {
        val ids = adapter.selectedIds()
        if (ids.isEmpty()) {
            Toast.makeText(this, R.string.bin_nothing_selected, Toast.LENGTH_SHORT).show()
            return
        }
        AlertDialog.Builder(this)
            .setTitle(R.string.bin_delete_selected_title)
            .setMessage(getString(R.string.bin_delete_selected_msg, ids.size))
            .setPositiveButton(R.string.bin_delete_selected_title) { _, _ ->
                Store.hardDeleteMany(ids)
                UiBus.notify(this)
                Toast.makeText(
                    this,
                    getString(R.string.bin_purged_selected_fmt, ids.size),
                    Toast.LENGTH_SHORT
                ).show()
                adapter.setSelecting(false)
                load()
            }
            .setNegativeButton(android.R.string.cancel, null)
            .show()
    }

    private fun confirmPurgeAll() {
        val count = adapter.itemCount
        if (count <= 0) return
        AlertDialog.Builder(this)
            .setTitle(R.string.bin_delete_all_title)
            .setMessage(getString(R.string.bin_delete_all_msg, count))
            .setPositiveButton(R.string.bin_delete_all) { _, _ ->
                val purged = Store.hardDeleteAllDeleted()
                UiBus.notify(this)
                Toast.makeText(
                    this,
                    getString(R.string.bin_purged_all_fmt, purged),
                    Toast.LENGTH_SHORT
                ).show()
                adapter.setSelecting(false)
                load()
            }
            .setNegativeButton(android.R.string.cancel, null)
            .show()
    }
}
