package com.workspace.worknote.ui

import android.graphics.Typeface
import android.os.Bundle
import android.speech.tts.TextToSpeech
import android.view.Gravity
import android.view.View
import android.widget.LinearLayout
import android.widget.TextView
import android.widget.Toast
import androidx.core.content.ContextCompat
import com.workspace.worknote.R
import com.workspace.worknote.databinding.ActivityHelpBinding
import com.workspace.worknote.databinding.ItemSettingRowBinding
import com.workspace.worknote.settings.AppSettings
import com.workspace.worknote.settings.ThemeHelper
import java.util.Locale

/**
 * 功能说明页：把 App 的全部功能逐项讲清楚（设置页自身除外），
 * 顶部可开关「内容播报」——开了之后点小节标题只读这一节，点按钮读整页。
 */
class HelpActivity : BaseActivity() {

    private lateinit var binding: ActivityHelpBinding
    private var tts: TextToSpeech? = null
    private var ttsReady = false
    private var ttsMissing = false
    private var ttsOn = false
    private var hintView: TextView? = null
    private var speakButton: TextView? = null

    /** 标题与正文成对排列：title, body, title, body … */
    private val sectionPairs = intArrayOf(
        R.string.help_1_title, R.string.help_1_body,
        R.string.help_2_title, R.string.help_2_body,
        R.string.help_3_title, R.string.help_3_body,
        R.string.help_4_title, R.string.help_4_body,
        R.string.help_5_title, R.string.help_5_body,
        R.string.help_6_title, R.string.help_6_body,
        R.string.help_7_title, R.string.help_7_body,
        R.string.help_8_title, R.string.help_8_body,
        R.string.help_9_title, R.string.help_9_body,
        R.string.help_10_title, R.string.help_10_body,
        R.string.help_11_title, R.string.help_11_body,
        R.string.help_12_title, R.string.help_12_body
    )

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        binding = ActivityHelpBinding.inflate(layoutInflater)
        setContentView(binding.root)
        binding.btnBack.setOnClickListener { finish() }
        ThemeHelper.applyPageBackground(binding.root)

        ttsOn = AppSettings.helpTts(this)
        initTts()
        render()
    }

    // ---------------- 播报 ----------------

    private fun initTts() {
        tts = TextToSpeech(this) { status ->
            ttsReady = status == TextToSpeech.SUCCESS
            if (ttsReady) {
                applyTtsLocale()
            } else {
                // 这台手机没装系统语音引擎：把话说清楚，而不是点了没反应
                ttsMissing = true
                hintView?.text = getString(R.string.help_tts_no_engine)
                toast(getString(R.string.help_tts_no_engine))
            }
        }
    }

    private fun applyTtsLocale() {
        val engine = tts ?: return
        val locale = runCatching { resources.configuration.locales[0] }
            .getOrNull() ?: Locale.getDefault()
        val result = engine.setLanguage(locale)
        if (result == TextToSpeech.LANG_MISSING_DATA || result == TextToSpeech.LANG_NOT_SUPPORTED) {
            engine.setLanguage(
                if (locale.language == "en") Locale.US else Locale.SIMPLIFIED_CHINESE
            )
        }
        engine.setSpeechRate(0.95f)
    }

    private fun speak(text: String) {
        if (!ttsReady) {
            toast(getString(R.string.help_tts_unavailable))
            return
        }
        tts?.speak(text, TextToSpeech.QUEUE_FLUSH, null, "worknote_help")
    }

    private fun speakWhole() {
        val builder = StringBuilder()
        builder.append(getString(R.string.help_intro)).append('\n')
        var i = 0
        while (i < sectionPairs.size) {
            builder.append(getString(sectionPairs[i])).append('\n')
            builder.append(getString(sectionPairs[i + 1])).append('\n')
            i += 2
        }
        speak(builder.toString())
    }

    private fun setTtsOn(on: Boolean) {
        ttsOn = on
        AppSettings.setHelpTts(this, on)
        if (!on) tts?.stop()
        hintView?.text = hintText()
        speakButton?.visibility = if (on) View.VISIBLE else View.GONE
        if (on) speakWhole()
    }

    private fun hintText(): String = when {
        ttsMissing -> getString(R.string.help_tts_no_engine)
        ttsOn -> getString(R.string.help_tts_on_hint)
        else -> getString(R.string.help_tts_off_hint)
    }

    // ---------------- 页面 ----------------

    private fun render() {
        val container = binding.helpContent
        container.removeAllViews()

        container.addView(textView(getString(R.string.help_intro), 12f, R.color.text_secondary, 4, false))

        // 内容播报开关
        val row = ItemSettingRowBinding.inflate(layoutInflater, container, false)
        row.rowTitle.text = getString(R.string.help_tts_title)
        row.rowSubtitle.text = getString(R.string.help_tts_sub)
        row.rowSubtitle.visibility = View.VISIBLE
        row.rowValue.visibility = View.GONE
        row.rowSwitch.visibility = View.VISIBLE
        row.rowSwitch.isChecked = ttsOn
        row.root.layoutParams = LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT,
            LinearLayout.LayoutParams.WRAP_CONTENT
        ).apply {
            topMargin = dp(14)
            marginStart = dp(16)
            marginEnd = dp(16)
        }
        row.root.isClickable = true
        row.root.isFocusable = true
        row.root.setOnClickListener { row.rowSwitch.isChecked = !row.rowSwitch.isChecked }
        row.rowSwitch.setOnCheckedChangeListener { _, value -> setTtsOn(value) }
        container.addView(row.root)

        hintView = textView(hintText(), 12f, R.color.text_secondary, 6, false)
        container.addView(hintView)

        speakButton = TextView(this).apply {
            text = getString(R.string.help_tts_speak_all)
            gravity = Gravity.CENTER
            setTextColor(android.graphics.Color.WHITE)
            textSize = 14f
            background = ContextCompat.getDrawable(this@HelpActivity, R.drawable.bg_button_primary)
            isClickable = true
            isFocusable = true
            visibility = if (ttsOn) View.VISIBLE else View.GONE
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, dp(44)
            ).apply {
                topMargin = dp(10)
                marginStart = dp(16)
                marginEnd = dp(16)
            }
            setOnClickListener { speakWhole() }
        }
        container.addView(speakButton)

        var i = 0
        while (i < sectionPairs.size) {
            val titleRes = sectionPairs[i]
            val bodyRes = sectionPairs[i + 1]
            val titleText = getString(titleRes)
            val bodyText = getString(bodyRes)

            val titleView = textView(titleText, 15f, R.color.text_primary, 22, true)
            titleView.isClickable = true
            titleView.isFocusable = true
            titleView.setOnClickListener {
                if (ttsOn) speak("$titleText。$bodyText")
                else toast(getString(R.string.help_tts_off_hint))
            }
            container.addView(titleView)

            container.addView(textView(bodyText, 13f, R.color.text_secondary, 4, false))
            i += 2
        }
    }

    private fun textView(
        content: String,
        size: Float,
        colorRes: Int,
        topMargin: Int,
        bold: Boolean
    ): TextView = TextView(this).apply {
        text = content
        textSize = size
        setTextColor(ContextCompat.getColor(this@HelpActivity, colorRes))
        if (bold) setTypeface(typeface, Typeface.BOLD)
        setLineSpacing(dp(3).toFloat(), 1.0f)
        layoutParams = LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT,
            LinearLayout.LayoutParams.WRAP_CONTENT
        ).apply {
            this.topMargin = dp(topMargin)
            marginStart = dp(16)
            marginEnd = dp(16)
        }
    }

    private fun dp(value: Int): Int = (value * resources.displayMetrics.density).toInt()

    private fun toast(message: String) {
        Toast.makeText(this, message, Toast.LENGTH_SHORT).show()
    }

    override fun onPause() {
        super.onPause()
        tts?.stop()
    }

    override fun onDestroy() {
        super.onDestroy()
        tts?.stop()
        tts?.shutdown()
        tts = null
        ttsReady = false
    }
}
