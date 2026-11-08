package com.workspace.worknote.ui

import android.content.Intent
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.view.animation.OvershootInterpolator
import com.workspace.worknote.R
import com.workspace.worknote.databinding.ActivitySplashBinding

/**
 * 启动页：品牌绿渐变 + 白色卡片托住图标 + 名称、口号、版本号。
 * 入场分四拍：图标卡片先“弹”出来 → 名称上浮 → 口号跟上 → 版本号最后淡入，
 * 停留到约 1.4 秒后淡出进主界面；点一下屏幕可以跳过。
 */
class SplashActivity : BaseActivity() {

    private lateinit var binding: ActivitySplashBinding
    private val handler = Handler(Looper.getMainLooper())
    private val enterMain = Runnable { goMain() }
    private var navigated = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        binding = ActivitySplashBinding.inflate(layoutInflater)
        setContentView(binding.root)

        binding.splashVersion.text =
            getString(R.string.about_version_fmt, packageVersion())

        playIntro()

        // 点一下可以跳过，不让人干等
        binding.splashRoot.setOnClickListener { goMain() }
        handler.postDelayed(enterMain, 1400L)
    }

    private fun playIntro() {
        val density = resources.displayMetrics.density

        // 1) 卡片：略小 + 略低 → 回弹到正常大小，像被“放”到屏幕上
        binding.splashCard.apply {
            alpha = 0f
            scaleX = 0.88f
            scaleY = 0.88f
            translationY = 24f * density
            animate()
                .alpha(1f)
                .scaleX(1f)
                .scaleY(1f)
                .translationY(0f)
                .setDuration(560L)
                .setInterpolator(OvershootInterpolator(0.9f))
                .start()
        }

        // 2) 名称：晚 140ms 上浮
        binding.splashTitle.apply {
            alpha = 0f
            translationY = 14f * density
            animate()
                .alpha(1f)
                .translationY(0f)
                .setStartDelay(140L)
                .setDuration(460L)
                .start()
        }

        // 3) 口号
        binding.splashSlogan.apply {
            alpha = 0f
            translationY = 10f * density
            animate()
                .alpha(1f)
                .translationY(0f)
                .setStartDelay(280L)
                .setDuration(460L)
                .start()
        }

        // 4) 版本号
        binding.splashVersion.apply {
            alpha = 0f
            animate()
                .alpha(1f)
                .setStartDelay(420L)
                .setDuration(420L)
                .start()
        }
    }

    private fun goMain() {
        if (navigated) return
        navigated = true
        handler.removeCallbacks(enterMain)
        startActivity(Intent(this, MainShellActivity::class.java))
        overridePendingTransition(android.R.anim.fade_in, android.R.anim.fade_out)
        finish()
    }

    private fun packageVersion(): String = try {
        packageManager.getPackageInfo(packageName, 0).versionName ?: "1.0.0"
    } catch (e: Exception) {
        "1.0.0"
    }

    override fun onDestroy() {
        handler.removeCallbacksAndMessages(null)
        super.onDestroy()
    }
}
