package com.workspace.worknote.ui

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.res.ColorStateList
import android.os.Bundle
import android.view.View
import androidx.appcompat.app.AppCompatActivity
import androidx.core.content.ContextCompat
import androidx.core.widget.ImageViewCompat
import androidx.fragment.app.Fragment
import com.workspace.worknote.R
import com.workspace.worknote.data.Store
import com.workspace.worknote.databinding.ActivityMainBinding
import com.workspace.worknote.logic.Channels
import com.workspace.worknote.logic.UiBus
import com.workspace.worknote.settings.ThemeHelper

/** 手机外壳：顶部没有导航栏，底部三个 Tab：主界面 / 日程 / 我 */
class MainShellActivity : BaseActivity() {

    private lateinit var binding: ActivityMainBinding
    private var currentTab = 0

    private val tags = arrayOf("tab_home", "tab_schedule", "tab_profile")

    private val refreshReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            updateBadge()
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        binding = ActivityMainBinding.inflate(layoutInflater)
        setContentView(binding.root)
        // 背景图铺在整个外壳上，三个 Tab 共用同一张底图（Tab 栏自带底色不受影响）
        ThemeHelper.applyPageBackground(binding.root)

        Store.init(this)
        Channels.ensure(this)

        binding.tabHome.setOnClickListener { showTab(0) }
        binding.tabSchedule.setOnClickListener { showTab(1) }
        binding.tabProfile.setOnClickListener { showTab(2) }

        showTab(if (savedInstanceState != null) currentTab else 0)
    }

    override fun onStart() {
        super.onStart()
        ContextCompat.registerReceiver(
            this,
            refreshReceiver,
            IntentFilter(UiBus.ACTION_REFRESH),
            ContextCompat.RECEIVER_NOT_EXPORTED
        )
        updateBadge()
    }

    override fun onStop() {
        super.onStop()
        runCatching { unregisterReceiver(refreshReceiver) }
    }

    private fun showTab(index: Int) {
        currentTab = index
        val manager = supportFragmentManager
        val transaction = manager.beginTransaction()
        tags.forEachIndexed { i, tag ->
            val existing = manager.findFragmentByTag(tag)
            if (i == index) {
                if (existing == null) {
                    transaction.add(R.id.fragmentHost, createFragment(i), tag)
                } else {
                    transaction.show(existing)
                }
            } else if (existing != null) {
                transaction.hide(existing)
            }
        }
        transaction.commit()
        updateTabs()
    }

    private fun createFragment(index: Int): Fragment = when (index) {
        0 -> HomeFragment()
        1 -> ScheduleFragment()
        else -> ProfileFragment()
    }

    private fun updateTabs() {
        val selected = ContextCompat.getColor(this, R.color.accent)
        val normal = ContextCompat.getColor(this, R.color.tab_unselected)
        val icons = arrayOf(binding.tabHomeIcon, binding.tabScheduleIcon, binding.tabProfileIcon)
        val labels = arrayOf(binding.tabHomeLabel, binding.tabScheduleLabel, binding.tabProfileLabel)

        icons.forEachIndexed { i, view ->
            ImageViewCompat.setImageTintList(
                view,
                ColorStateList.valueOf(if (i == currentTab) selected else normal)
            )
        }
        labels.forEachIndexed { i, view ->
            view.setTextColor(if (i == currentTab) selected else normal)
        }
        updateBadge()
    }

    private fun updateBadge() {
        val total = Store.activeTotal()
        binding.tabHomeBadge.visibility = if (total > 0) View.VISIBLE else View.GONE
        binding.tabHomeBadge.text = if (total > 99) "99+" else total.toString()
    }
}
