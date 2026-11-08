package com.workspace.worknote.ui

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Bundle
import android.view.View
import android.widget.EditText
import android.widget.PopupMenu
import androidx.activity.result.contract.ActivityResultContracts
import androidx.appcompat.app.AlertDialog
import androidx.core.content.ContextCompat
import androidx.fragment.app.Fragment
import androidx.recyclerview.widget.LinearLayoutManager
import com.workspace.worknote.R
import com.workspace.worknote.data.Note
import com.workspace.worknote.data.Status
import com.workspace.worknote.data.Store
import com.workspace.worknote.databinding.FragmentHomeBinding
import com.workspace.worknote.logic.UiBus

/** 主界面：仿微信会话列表，一条便签算一次会话 */
class HomeFragment : Fragment(R.layout.fragment_home) {

    private var binding: FragmentHomeBinding? = null
    private val adapter = NoteAdapter { note -> openDetail(note) }
    private var keyword = ""
    private var activeOnly = false

    private val editLauncher =
        registerForActivityResult(ActivityResultContracts.StartActivityForResult()) { reload() }

    private val refreshReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            reload()
        }
    }

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)
        val viewBinding = FragmentHomeBinding.bind(view)
        binding = viewBinding

        viewBinding.noteList.layoutManager = LinearLayoutManager(requireContext())
        viewBinding.noteList.adapter = adapter
        viewBinding.btnAdd.setOnClickListener { openEdit(null) }
        viewBinding.btnMore.setOnClickListener { showMoreMenu() }

        reload()
    }

    override fun onResume() {
        super.onResume()
        reload()
    }

    override fun onStart() {
        super.onStart()
        ContextCompat.registerReceiver(
            requireContext(),
            refreshReceiver,
            IntentFilter(UiBus.ACTION_REFRESH),
            ContextCompat.RECEIVER_NOT_EXPORTED
        )
    }

    override fun onStop() {
        super.onStop()
        runCatching { requireContext().unregisterReceiver(refreshReceiver) }
    }

    override fun onDestroyView() {
        super.onDestroyView()
        binding = null
    }

    private fun reload() {
        val viewBinding = binding ?: return
        var list = Store.visible()
        if (activeOnly) list = list.filter { it.isActive }
        if (keyword.isNotBlank()) {
            val k = keyword.trim()
            list = list.filter { it.title.contains(k, true) || it.remark.contains(k, true) }
        }
        list = list.sortedWith(
            compareBy(
                { statusRank(it.status) },
                { if (it.isActive && it.remindAt > 0L) it.remindAt else Long.MAX_VALUE }
            )
        )
        adapter.submit(list)
        viewBinding.emptyView.visibility = if (list.isEmpty()) View.VISIBLE else View.GONE
        viewBinding.emptyView.text = when {
            keyword.isNotBlank() -> getString(R.string.home_empty_keyword, keyword)
            activeOnly -> getString(R.string.home_empty_active)
            else -> getString(R.string.home_empty)
        }
    }

    private fun statusRank(status: String): Int = when (status) {
        Status.READY -> 0
        Status.PENDING -> 1
        Status.POSTPONED -> 2
        Status.DONE -> 3
        else -> 4
    }

    private fun showMoreMenu() {
        val viewBinding = binding ?: return
        val menu = PopupMenu(requireContext(), viewBinding.btnMore)
        menu.menu.add(0, MENU_NEW, 0, R.string.new_note)
        menu.menu.add(0, MENU_TOGGLE_FILTER, 1, if (activeOnly) R.string.menu_show_all else R.string.menu_active_only)
        menu.menu.add(0, MENU_SEARCH, 2, R.string.menu_search)
        menu.menu.add(0, MENU_BIN, 3, R.string.recycle_bin)
        menu.setOnMenuItemClickListener { item ->
            when (item.itemId) {
                MENU_NEW -> openEdit(null)
                MENU_TOGGLE_FILTER -> {
                    activeOnly = !activeOnly
                    reload()
                }
                MENU_SEARCH -> searchDialog()
                MENU_BIN -> startActivity(Intent(requireContext(), RecycleBinActivity::class.java))
            }
            true
        }
        menu.show()
    }

    private fun searchDialog() {
        val input = EditText(requireContext()).apply {
            hint = getString(R.string.search_hint)
            setText(keyword)
            setSingleLine(true)
            setPadding(dp(8), dp(8), dp(8), dp(8))
        }
        AlertDialog.Builder(requireContext())
            .setTitle(R.string.search_title)
            .setView(input)
            .setPositiveButton(R.string.search_action) { _, _ ->
                keyword = input.text.toString()
                reload()
            }
            .setNegativeButton(R.string.search_clear) { _, _ ->
                keyword = ""
                reload()
            }
            .setNeutralButton(android.R.string.cancel, null)
            .show()
    }

    private fun openDetail(note: Note) {
        startActivity(
            Intent(requireContext(), NoteDetailActivity::class.java)
                .putExtra(NoteDetailActivity.EXTRA_NOTE_ID, note.id)
        )
    }

    private fun openEdit(note: Note?) {
        val intent = Intent(requireContext(), NoteEditActivity::class.java)
        if (note != null) intent.putExtra(NoteEditActivity.EXTRA_NOTE_ID, note.id)
        editLauncher.launch(intent)
    }

    private fun dp(value: Int): Int =
        (value * resources.displayMetrics.density).toInt()

    companion object {
        private const val MENU_NEW = 1
        private const val MENU_TOGGLE_FILTER = 2
        private const val MENU_SEARCH = 3
        private const val MENU_BIN = 4
    }
}
