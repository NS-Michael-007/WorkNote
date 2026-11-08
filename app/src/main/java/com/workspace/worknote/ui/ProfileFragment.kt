package com.workspace.worknote.ui

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.view.View
import android.widget.LinearLayout
import android.widget.SeekBar
import android.widget.TextView
import android.widget.Toast
import androidx.activity.result.contract.ActivityResultContracts
import androidx.appcompat.app.AlertDialog
import androidx.core.content.ContextCompat
import androidx.fragment.app.Fragment
import com.workspace.worknote.R
import com.workspace.worknote.data.BackupManager
import com.workspace.worknote.data.Store
import com.workspace.worknote.databinding.FragmentProfileBinding
import com.workspace.worknote.databinding.ItemSettingRowBinding
import com.workspace.worknote.logic.Perms
import com.workspace.worknote.logic.ReminderScheduler
import com.workspace.worknote.logic.UiBus
import com.workspace.worknote.settings.AppSettings
import com.workspace.worknote.settings.RingtoneStore
import com.workspace.worknote.settings.ThemeHelper

/**
 * 我：权限引导、界面与显示、存储空间、通知、闹钟与提醒、备份、关于。
 * 设置项统一用 item_setting_row 逐行拼出来，避免一页几十个重复的 XML 块。
 */
class ProfileFragment : Fragment(R.layout.fragment_profile) {

    private var binding: FragmentProfileBinding? = null

    private var statusOverlay: TextView? = null
    private var statusBattery: TextView? = null
    private var statusNotify: TextView? = null
    private var statusExact: TextView? = null

    private val pickImage =
        registerForActivityResult(ActivityResultContracts.GetContent()) { uri ->
            if (uri != null) applyBackground(uri)
        }

    private val importLauncher =
        registerForActivityResult(ActivityResultContracts.OpenDocument()) { uri ->
            if (uri != null) confirmImport(uri)
        }

    /** 选本地音频当提醒铃声 */
    private val pickRingtone =
        registerForActivityResult(ActivityResultContracts.OpenDocument()) { uri ->
            if (uri != null) applyRingtone(uri)
        }

    private var ringtoneRowValue: TextView? = null

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)
        val viewBinding = FragmentProfileBinding.bind(view)
        binding = viewBinding

        buildSettings()
        refreshPermissions()
    }

    override fun onResume() {
        super.onResume()
        refreshPermissions()
    }

    override fun onDestroyView() {
        super.onDestroyView()
        binding = null
        statusOverlay = null
        statusBattery = null
        statusNotify = null
        statusExact = null
    }

    // ---------------- 页面拼装 ----------------

    private fun buildSettings() {
        val context = requireContext()

        section(getString(R.string.perm_section_title), getString(R.string.perm_section_hint))

        statusOverlay = addRow(getString(R.string.perm_overlay), null, getString(R.string.status_go)) {
            openOverlaySettings()
        }.rowValue
        statusBattery = addRow(getString(R.string.perm_battery), null, getString(R.string.status_go)) {
            openBatterySettings()
        }.rowValue
        statusNotify = addRow(getString(R.string.perm_notify), null, getString(R.string.status_go)) {
            openNotificationSettings()
        }.rowValue
        statusExact = addRow(getString(R.string.perm_exact), null, getString(R.string.status_go)) {
            openExactAlarmSettings()
        }.rowValue

        // ---- 界面与显示 ----
        section(getString(R.string.appearance_section), getString(R.string.appearance_hint))

        addRow(
            getString(R.string.bg_title),
            null,
            getString(if (ThemeHelper.hasBackground(context)) R.string.bg_custom else R.string.bg_default)
        ) { showBackgroundDialog() }

        addRow(getString(R.string.dark_title), null, darkModeLabel()) { showDarkModeDialog() }

        addRow(
            getString(R.string.font_title),
            null,
            getString(R.string.font_level_fmt, AppSettings.fontLevel(context))
        ) { showFontDialog() }

        addRow(getString(R.string.lang_title), null, languageLabel()) { showLanguageDialog() }

        addRow(
            getString(R.string.translate_title),
            getString(R.string.translate_sub),
            null
        ) { showTranslateInfo() }

        // ---- 存储空间 ----
        section(getString(R.string.storage_section), null)
        addRow(getString(R.string.storage_title), null, storageSummary()) { showStorageDialog() }

        // ---- 通知 ----
        section(getString(R.string.notify_section), null)

        switchRow(getString(R.string.notify_sound), AppSettings.notifySound(context)) { on ->
            AppSettings.setNotifySound(context, on)
        }
        switchRow(getString(R.string.notify_vibrate), AppSettings.notifyVibrate(context)) { on ->
            AppSettings.setNotifyVibrate(context, on)
        }
        switchRow(getString(R.string.notify_screen_on), AppSettings.notifyScreenOn(context)) { on ->
            AppSettings.setNotifyScreenOn(context, on)
        }

        ringtoneRowValue = addRow(
            getString(R.string.ringtone_title),
            getString(R.string.ringtone_hint),
            ringtoneLabel()
        ) { showRingtoneDialog() }.rowValue

        // ---- 闹钟与提醒 ----
        section(getString(R.string.alarm_section), null)

        addRow(
            getString(R.string.alarm_delay_title),
            null,
            getString(R.string.minutes_fmt, AppSettings.defaultDelayMinutes(context))
        ) { showDelayDialog() }

        addRow(
            getString(R.string.alarm_repeat_title),
            null,
            getString(R.string.minutes_fmt, AppSettings.defaultRepeatMinutes(context))
        ) { showRepeatDialog() }

        switchRow(
            getString(R.string.alarm_exact_title),
            AppSettings.useExactAlarm(context),
            getString(R.string.alarm_exact_sub)
        ) { on ->
            AppSettings.setUseExactAlarm(context, on)
            ReminderScheduler.rescheduleAll(context)
            toast(getString(R.string.alarm_rescheduled))
        }

        // ---- 数据备份 ----
        section(getString(R.string.backup_section), getString(R.string.backup_hint))
        primaryButton(getString(R.string.backup_export)) { exportBackup() }
        primaryButton(getString(R.string.backup_import)) {
            importLauncher.launch(arrayOf("application/json", "text/plain", "*/*"))
        }

        // ---- 关于 ----
        section(getString(R.string.about_section), getString(R.string.about_text))
        addRow(getString(R.string.about_version_fmt, versionName()), null, null, null)
    }

    private fun section(title: String, hint: String?) {
        val container = binding?.profileContent ?: return
        val titleView = TextView(requireContext()).apply {
            text = title
            setTextColor(ContextCompat.getColor(requireContext(), R.color.text_primary))
            textSize = 14f
            setTypeface(typeface, android.graphics.Typeface.BOLD)
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply {
                topMargin = dp(24)
                marginStart = dp(16)
                marginEnd = dp(16)
            }
        }
        container.addView(titleView)

        if (hint != null) {
            val hintView = TextView(requireContext()).apply {
                text = hint
                setTextColor(ContextCompat.getColor(requireContext(), R.color.text_secondary))
                textSize = 12f
                layoutParams = LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.MATCH_PARENT,
                    LinearLayout.LayoutParams.WRAP_CONTENT
                ).apply {
                    topMargin = dp(4)
                    marginStart = dp(16)
                    marginEnd = dp(16)
                }
            }
            container.addView(hintView)
        }
    }

    private fun addRow(
        title: String,
        subtitle: String?,
        value: String?,
        onClick: (() -> Unit)?
    ): ItemSettingRowBinding {
        val container = binding?.profileContent ?: error("页面还没准备好")
        val row = ItemSettingRowBinding.inflate(layoutInflater, container, false)
        row.rowTitle.text = title
        row.rowSubtitle.text = subtitle ?: ""
        row.rowSubtitle.visibility = if (subtitle.isNullOrEmpty()) View.GONE else View.VISIBLE
        row.rowValue.text = value ?: ""
        row.rowValue.visibility = if (value.isNullOrEmpty()) View.GONE else View.VISIBLE
        row.rowSwitch.visibility = View.GONE
        row.root.layoutParams = LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT,
            LinearLayout.LayoutParams.WRAP_CONTENT
        ).apply {
            topMargin = dp(10)
            marginStart = dp(16)
            marginEnd = dp(16)
        }
        if (onClick != null) {
            row.root.isClickable = true
            row.root.isFocusable = true
            row.root.setOnClickListener { onClick() }
        }
        (container as LinearLayout).addView(row.root)
        return row
    }

    private fun switchRow(
        title: String,
        checked: Boolean,
        subtitle: String? = null,
        onToggle: (Boolean) -> Unit
    ): ItemSettingRowBinding {
        val row = addRow(title, subtitle, null, null)
        row.rowValue.visibility = View.GONE
        row.rowSwitch.visibility = View.VISIBLE
        row.rowSwitch.isChecked = checked
        row.rowSwitch.setOnCheckedChangeListener { _, value -> onToggle(value) }
        row.root.isClickable = true
        row.root.isFocusable = true
        row.root.setOnClickListener {
            row.rowSwitch.isChecked = !row.rowSwitch.isChecked
        }
        return row
    }

    private fun primaryButton(text: String, onClick: () -> Unit) {
        val container = binding?.profileContent ?: return
        val button = TextView(requireContext()).apply {
            this.text = text
            gravity = android.view.Gravity.CENTER
            setTextColor(android.graphics.Color.WHITE)
            textSize = 14f
            background = ContextCompat.getDrawable(requireContext(), R.drawable.bg_button_primary)
            isClickable = true
            isFocusable = true
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, dp(44)
            ).apply {
                topMargin = dp(10)
                marginStart = dp(16)
                marginEnd = dp(16)
            }
            setOnClickListener { onClick() }
        }
        container.addView(button)
    }

    // ---------------- 权限 ----------------

    private fun refreshPermissions() {
        val context = requireContext()
        paint(statusOverlay, Perms.canOverlay(context), permRowLabel(context, Perms.canOverlay(context)))
        paint(
            statusBattery,
            Perms.ignoringBatteryOptimization(context),
            permRowLabel(context, Perms.ignoringBatteryOptimization(context))
        )
        paint(statusNotify, Perms.canNotify(context), permRowLabel(context, Perms.canNotify(context)))
        val exact = ReminderScheduler.canScheduleExact(context)
        paint(statusExact, exact, permRowLabel(context, exact))
    }

    private fun permRowLabel(context: android.content.Context, granted: Boolean): String =
        context.getString(if (granted) R.string.status_on else R.string.status_off)

    private fun paint(view: TextView?, granted: Boolean, text: String) {
        val target = view ?: return
        target.text = text
        target.setTextColor(
            ContextCompat.getColor(
                requireContext(),
                if (granted) R.color.accent else R.color.text_secondary
            )
        )
    }

    private fun openOverlaySettings() {
        startSafely(
            Intent(
                Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                Uri.parse("package:" + requireContext().packageName)
            )
        )
    }

    private fun openBatterySettings() {
        val context = requireContext()
        val packageUri = Uri.parse("package:" + context.packageName)
        try {
            startActivity(Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS, packageUri))
        } catch (e: Exception) {
            startSafely(Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS))
        }
    }

    private fun openNotificationSettings() {
        val context = requireContext()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            ContextCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS)
            != PackageManager.PERMISSION_GRANTED
        ) {
            requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), REQ_NOTIFY)
            return
        }
        startSafely(
            Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                .putExtra(Settings.EXTRA_APP_PACKAGE, context.packageName)
        )
    }

    private fun openExactAlarmSettings() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) {
            toast(getString(R.string.exact_not_needed))
            return
        }
        startSafely(
            Intent(
                Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM,
                Uri.parse("package:" + requireContext().packageName)
            )
        )
    }

    private fun startSafely(intent: Intent) {
        try {
            startActivity(intent)
        } catch (e: Exception) {
            toast(getString(R.string.cant_open_settings))
        }
    }

    // ---------------- 界面与显示 ----------------

    private fun darkModeLabel(): String = when (AppSettings.darkMode(requireContext())) {
        AppSettings.DARK_LIGHT -> getString(R.string.dark_light)
        AppSettings.DARK_NIGHT -> getString(R.string.dark_night)
        else -> getString(R.string.dark_follow)
    }

    private fun languageLabel(): String = when (AppSettings.language(requireContext())) {
        AppSettings.LANG_ZH -> getString(R.string.lang_zh)
        AppSettings.LANG_ZH_HANT -> getString(R.string.lang_zh_hant)
        AppSettings.LANG_EN -> getString(R.string.lang_en)
        else -> getString(R.string.lang_follow)
    }

    private fun showDarkModeDialog() {
        val labels = arrayOf(
            getString(R.string.dark_follow),
            getString(R.string.dark_light),
            getString(R.string.dark_night)
        )
        val values = intArrayOf(
            AppSettings.DARK_FOLLOW_SYSTEM,
            AppSettings.DARK_LIGHT,
            AppSettings.DARK_NIGHT
        )
        val current = values.indexOf(AppSettings.darkMode(requireContext())).coerceAtLeast(0)
        AlertDialog.Builder(requireContext())
            .setTitle(R.string.dark_dialog)
            .setSingleChoiceItems(labels, current) { dialog, which ->
                AppSettings.setDarkMode(requireContext(), values[which])
                ThemeHelper.applyNightMode(requireContext())
                dialog.dismiss()
                activity?.recreate()
            }
            .setNegativeButton(android.R.string.cancel, null)
            .show()
    }

    private fun showFontDialog() {
        val context = requireContext()
        val density = resources.displayMetrics.density
        fun px(value: Int): Int = (value * density).toInt()

        val container = LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(px(20), px(16), px(20), px(8))
        }
        val preview = TextView(context).apply {
            text = context.getString(R.string.font_preview)
            setTextColor(ContextCompat.getColor(context, R.color.text_primary))
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            )
        }
        val levelLabel = TextView(context).apply {
            setTextColor(ContextCompat.getColor(context, R.color.text_secondary))
            textSize = 12f
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply { topMargin = px(8) }
        }
        val bar = SeekBar(context).apply {
            min = 1
            max = 10
            progress = AppSettings.fontLevel(context)
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply { topMargin = px(12) }
        }
        fun paint(level: Int) {
            preview.textSize = 14f * (0.80f + level * 0.05f)
            levelLabel.text = context.getString(R.string.font_level_fmt, level)
        }
        paint(AppSettings.fontLevel(context))
        bar.setOnSeekBarChangeListener(object : SeekBar.OnSeekBarChangeListener {
            override fun onProgressChanged(seekBar: SeekBar?, progress: Int, fromUser: Boolean) =
                paint(progress)

            override fun onStartTrackingTouch(seekBar: SeekBar?) = Unit
            override fun onStopTrackingTouch(seekBar: SeekBar?) = Unit
        })

        container.addView(preview)
        container.addView(levelLabel)
        container.addView(bar)

        AlertDialog.Builder(context)
            .setTitle(R.string.font_dialog)
            .setView(container)
            .setPositiveButton(android.R.string.ok) { _, _ ->
                AppSettings.setFontLevel(context, bar.progress)
                activity?.recreate()
            }
            .setNegativeButton(android.R.string.cancel, null)
            .show()
    }

    private fun showLanguageDialog() {
        val labels = arrayOf(
            getString(R.string.lang_follow),
            getString(R.string.lang_zh),
            getString(R.string.lang_zh_hant),
            getString(R.string.lang_en)
        )
        val values = arrayOf(
            AppSettings.LANG_SYSTEM,
            AppSettings.LANG_ZH,
            AppSettings.LANG_ZH_HANT,
            AppSettings.LANG_EN
        )
        val current = values.indexOf(AppSettings.language(requireContext())).coerceAtLeast(0)
        AlertDialog.Builder(requireContext())
            .setTitle(R.string.lang_dialog)
            .setSingleChoiceItems(labels, current) { dialog, which ->
                AppSettings.setLanguage(requireContext(), values[which])
                dialog.dismiss()
                activity?.recreate()
            }
            .setNegativeButton(android.R.string.cancel, null)
            .show()
    }

    // ---------------- 提醒铃声 ----------------

    private fun ringtoneLabel(): String {
        val file = RingtoneStore.current(requireContext())
        if (file == null) return getString(R.string.ringtone_default)
        val saved = AppSettings.ringtoneLabel(requireContext())
        return saved ?: file.name
    }

    private fun showRingtoneDialog() {
        val items = arrayOf(
            getString(R.string.ringtone_pick),
            getString(R.string.ringtone_reset)
        )
        AlertDialog.Builder(requireContext())
            .setTitle(R.string.ringtone_dialog)
            .setItems(items) { dialog, which ->
                dialog.dismiss()
                if (which == 0) {
                    // 只挑音频，别让用户选到文档或视频
                    pickRingtone.launch(arrayOf("audio/*"))
                } else {
                    RingtoneStore.reset(requireContext())
                    ringtoneRowValue?.text = getString(R.string.ringtone_default)
                    toast(getString(R.string.ringtone_reset_done))
                }
            }
            .setNegativeButton(android.R.string.cancel, null)
            .show()
    }

    private fun applyRingtone(uri: Uri) {
        val context = requireContext()
        try {
            // 有些来源（网盘、下载）拿不到持久授权，所以先复制进私有目录再播
            runCatching {
                context.contentResolver.takePersistableUriPermission(
                    uri, Intent.FLAG_GRANT_READ_URI_PERMISSION
                )
            }
            val file = RingtoneStore.import(context, uri)
            val label = AppSettings.ringtoneLabel(context) ?: file.name
            ringtoneRowValue?.text = label
            toast(getString(R.string.ringtone_applied, label))
            // 立刻试听一次，确认真能播
            com.workspace.worknote.logic.Alerts.fire(context)
        } catch (e: Exception) {
            toast(getString(R.string.ringtone_import_failed, e.message ?: ""))
        }
    }

    private fun showTranslateInfo() {
        AlertDialog.Builder(requireContext())
            .setTitle(R.string.translate_dialog)
            .setMessage(R.string.translate_dialog_msg)
            .setPositiveButton(android.R.string.ok, null)
            .show()
    }

    private fun showBackgroundDialog() {
        val hasBg = ThemeHelper.hasBackground(requireContext())
        val items = if (hasBg) {
            arrayOf(getString(R.string.bg_pick), getString(R.string.bg_reset))
        } else {
            arrayOf(getString(R.string.bg_pick))
        }
        AlertDialog.Builder(requireContext())
            .setTitle(R.string.bg_dialog)
            .setItems(items) { dialog, which ->
                if (which == 0) {
                    pickImage.launch("image/*")
                } else {
                    ThemeHelper.clearBackground(requireContext())
                    toast(getString(R.string.bg_reset_done))
                    activity?.recreate()
                }
                dialog.dismiss()
            }
            .setNegativeButton(android.R.string.cancel, null)
            .show()
    }

    private fun applyBackground(uri: Uri) {
        val ok = ThemeHelper.saveBackground(requireContext(), uri)
        if (!ok) {
            toast(getString(R.string.bg_failed))
            return
        }
        toast(getString(R.string.bg_applied))
        activity?.recreate()
    }

    // ---------------- 存储空间 ----------------

    private fun storageSummary(): String = formatSize(databaseSize() + backgroundSize())

    private fun databaseSize(): Long {
        val file = requireContext().getDatabasePath("worknote.db")
        return if (file.exists()) file.length() else 0L
    }

    private fun backgroundSize(): Long {
        val file = ThemeHelper.backgroundFile(requireContext())
        return if (file.exists()) file.length() else 0L
    }

    private fun showStorageDialog() {
        val message = buildString {
            append(getString(R.string.storage_notes_fmt, Store.all().size)).append('\n')
            append(getString(R.string.storage_db_fmt, formatSize(databaseSize()))).append('\n')
            append(
                if (backgroundSize() > 0L) getString(R.string.storage_bg_fmt, formatSize(backgroundSize()))
                else getString(R.string.storage_bg_none)
            )
        }
        AlertDialog.Builder(requireContext())
            .setTitle(R.string.storage_dialog)
            .setMessage(message)
            .setPositiveButton(R.string.storage_clear) { _, _ -> clearCache() }
            .setNegativeButton(android.R.string.ok, null)
            .show()
    }

    private fun clearCache() {
        val context = requireContext()
        var freed = 0L
        listOf(context.cacheDir, context.codeCacheDir).forEach { dir ->
            dir.listFiles()?.forEach { file ->
                freed += file.length()
                runCatching { file.delete() }
            }
        }
        toast(getString(R.string.storage_cleared) + " " + formatSize(freed))
    }

    private fun formatSize(bytes: Long): String = when {
        bytes >= 1024L * 1024L -> String.format("%.1f MB", bytes / 1024.0 / 1024.0)
        bytes >= 1024L -> String.format("%.1f KB", bytes / 1024.0)
        else -> "$bytes B"
    }

    // ---------------- 闹钟与提醒默认值 ----------------

    private fun showDelayDialog() {
        val values = intArrayOf(10, 30, 60)
        val labels = values.map { getString(R.string.minutes_fmt, it) }.toTypedArray()
        val current = values.indexOf(AppSettings.defaultDelayMinutes(requireContext())).coerceAtLeast(0)
        AlertDialog.Builder(requireContext())
            .setTitle(R.string.alarm_delay_title)
            .setSingleChoiceItems(labels, current) { dialog, which ->
                AppSettings.setDefaultDelayMinutes(requireContext(), values[which])
                dialog.dismiss()
                refreshRows()
            }
            .setNegativeButton(android.R.string.cancel, null)
            .show()
    }

    private fun showRepeatDialog() {
        val values = intArrayOf(5, 10, 15, 30, 60)
        val labels = values.map { getString(R.string.minutes_fmt, it) }.toTypedArray()
        val current = values.indexOf(AppSettings.defaultRepeatMinutes(requireContext())).coerceAtLeast(0)
        AlertDialog.Builder(requireContext())
            .setTitle(R.string.alarm_repeat_title)
            .setSingleChoiceItems(labels, current) { dialog, which ->
                AppSettings.setDefaultRepeatMinutes(requireContext(), values[which])
                dialog.dismiss()
                refreshRows()
            }
            .setNegativeButton(android.R.string.cancel, null)
            .show()
    }

    /** 改完设置后重建整页，保证显示的当前值是最新的 */
    private fun refreshRows() {
        val content = binding?.profileContent ?: return
        content.removeAllViews()
        buildSettings()
        refreshPermissions()
    }

    // ---------------- 备份 ----------------

    private fun exportBackup() {
        val context = requireContext()
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q &&
            ContextCompat.checkSelfPermission(context, Manifest.permission.WRITE_EXTERNAL_STORAGE)
            != PackageManager.PERMISSION_GRANTED
        ) {
            requestPermissions(arrayOf(Manifest.permission.WRITE_EXTERNAL_STORAGE), REQ_STORAGE)
            return
        }
        doExport()
    }

    private fun doExport() {
        try {
            val where = BackupManager.export(requireContext())
            toast(getString(R.string.backup_saved_fmt, where))
        } catch (e: Exception) {
            toast(getString(R.string.backup_failed_fmt, e.message ?: ""))
        }
    }

    private fun confirmImport(uri: Uri) {
        AlertDialog.Builder(requireContext())
            .setTitle(R.string.backup_import)
            .setMessage(R.string.import_confirm)
            .setPositiveButton(R.string.import_ok) { _, _ ->
                try {
                    val count = BackupManager.importFrom(requireContext(), uri)
                    UiBus.notify(requireContext())
                    refreshPermissions()
                    toast(getString(R.string.import_done_fmt, count))
                } catch (e: Exception) {
                    toast(getString(R.string.import_failed_fmt, e.message ?: ""))
                }
            }
            .setNegativeButton(android.R.string.cancel, null)
            .show()
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == REQ_NOTIFY) refreshPermissions()
        if (requestCode == REQ_STORAGE) {
            if (grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
                doExport()
            } else {
                toast(getString(R.string.no_storage_perm))
            }
        }
    }

    // ---------------- 小工具 ----------------

    private fun versionName(): String = runCatching {
        requireContext().packageManager.getPackageInfo(requireContext().packageName, 0).versionName
    }.getOrNull() ?: "1.0.0"

    private fun dp(value: Int): Int = (value * resources.displayMetrics.density).toInt()

    private fun toast(message: String) {
        Toast.makeText(requireContext(), message, Toast.LENGTH_SHORT).show()
    }

    companion object {
        private const val REQ_NOTIFY = 1001
        private const val REQ_STORAGE = 1002
    }
}
