package com.workspace.worknote.settings

import android.content.Context
import android.content.res.Configuration
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Color
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.ColorDrawable
import android.graphics.drawable.Drawable
import android.graphics.drawable.LayerDrawable
import android.net.Uri
import android.view.Gravity
import android.view.View
import androidx.appcompat.app.AppCompatDelegate
import java.io.File

/**
 * 深色模式 / 字号缩放 / 语言 / 背景图 四项统一处理。
 * Activity 在 attachBaseContext 里调 wrap()，页面根布局在加载完成后调 applyPageBackground()。
 */
object ThemeHelper {

    private const val BG_FILE = "page_background.jpg"

    // ---------------- 深色模式 ----------------
    fun applyNightMode(context: Context) {
        val mode = when (AppSettings.darkMode(context)) {
            AppSettings.DARK_LIGHT -> AppCompatDelegate.MODE_NIGHT_NO
            AppSettings.DARK_NIGHT -> AppCompatDelegate.MODE_NIGHT_YES
            else -> AppCompatDelegate.MODE_NIGHT_FOLLOW_SYSTEM
        }
        if (AppCompatDelegate.getDefaultNightMode() != mode) {
            AppCompatDelegate.setDefaultNightMode(mode)
        }
    }

    fun isNight(context: Context): Boolean =
        (context.resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK) ==
            Configuration.UI_MODE_NIGHT_YES

    // ---------------- 字号 + 语言 ----------------
    fun wrap(base: Context): Context {
        val config = Configuration(base.resources.configuration)
        config.fontScale = AppSettings.fontScale(base)
        AppSettings.localeFor(base)?.let { config.setLocale(it) }
        return base.createConfigurationContext(config)
    }

    // ---------------- 背景图 ----------------
    fun backgroundFile(context: Context): File = File(context.filesDir, BG_FILE)

    fun hasBackground(context: Context): Boolean = backgroundFile(context).exists()

    /** 把相册里选中的图存成本地文件，返回是否成功 */
    fun saveBackground(context: Context, uri: Uri): Boolean {
        return try {
            val resolver = context.contentResolver
            val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
            resolver.openInputStream(uri)?.use { BitmapFactory.decodeStream(it, null, bounds) }
            if (bounds.outWidth <= 0 || bounds.outHeight <= 0) return false
            val sample = sampleSize(bounds.outWidth, bounds.outHeight, 1440)
            val options = BitmapFactory.Options().apply { inSampleSize = sample }
            val bitmap = resolver.openInputStream(uri)?.use {
                BitmapFactory.decodeStream(it, null, options)
            } ?: return false
            val target = backgroundFile(context)
            target.outputStream().use { out ->
                bitmap.compress(Bitmap.CompressFormat.JPEG, 88, out)
            }
            AppSettings.setBackgroundPath(context, target.absolutePath)
            invalidateBackgroundCache()
            true
        } catch (e: Exception) {
            false
        }
    }

    fun clearBackground(context: Context) {
        runCatching { backgroundFile(context).delete() }
        AppSettings.setBackgroundPath(context, null)
        invalidateBackgroundCache()
    }

    /** 背景图做了虚化处理，按「文件路径 + 大小 + 深色模式」缓存，避免每次切页都重新解码 */
    private var cachedBg: Drawable? = null
    private var cachedKey: String? = null

    fun invalidateBackgroundCache() {
        cachedBg = null
        cachedKey = null
    }

    /**
     * 给页面根布局铺背景：整图先虚化，再压一层轻雾。
     * 虚化是为了让照片在「日程 / 我」这类白卡片密集的页面上也能透出来、又不干扰看字。
     */
    fun applyPageBackground(root: View) {
        val ctx = root.context
        val file = File(AppSettings.backgroundPath(ctx) ?: backgroundFile(ctx).absolutePath)
        if (!file.exists()) return

        val night = isNight(ctx)
        val key = file.absolutePath + ":" + file.length() + ":" + file.lastModified() + ":" + night
        if (cachedKey != key || cachedBg == null) {
            val bitmap = runCatching { blurred(file) }.getOrNull() ?: return
            val scrim = if (night) Color.argb(0xB4, 0x11, 0x11, 0x11)
            else Color.argb(0x9E, 0xF5, 0xF5, 0xF5)
            cachedBg = LayerDrawable(
                arrayOf<Drawable>(
                    BitmapDrawable(ctx.resources, bitmap).apply { gravity = Gravity.FILL },
                    ColorDrawable(scrim)
                )
            )
            cachedKey = key
        }
        // 每个 View 拿一份独立副本，避免同一 Drawable 被多个页面同时持有
        root.background = cachedBg?.constantState?.newDrawable(root.resources) ?: cachedBg
    }

    /**
     * 虚化：先按 1/12 缩小（等于一次大半径采样），再用带双线性过滤的方式放大回原尺寸。
     * 三步缩放近似高斯模糊，比 RenderScript 轻量，minSdk 26 也能用。
     */
    private fun blurred(file: File): Bitmap? {
        val src = decodeSampled(file, 900) ?: return null
        val w = src.width
        val h = src.height
        if (w <= 0 || h <= 0) return null
        val small = Bitmap.createScaledBitmap(
            src,
            (w / 12).coerceAtLeast(16),
            (h / 12).coerceAtLeast(16),
            true
        )
        val mid = Bitmap.createScaledBitmap(small, (w / 3).coerceAtLeast(24), (h / 3).coerceAtLeast(24), true)
        val out = Bitmap.createScaledBitmap(mid, w, h, true)
        if (small !== src) small.recycle()
        if (mid !== src && mid !== out) mid.recycle()
        out.density = Bitmap.DENSITY_NONE
        return out
    }

    private fun decodeSampled(file: File, maxWidth: Int): Bitmap? {
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeFile(file.absolutePath, bounds)
        val options = BitmapFactory.Options().apply {
            inSampleSize = sampleSize(bounds.outWidth, bounds.outHeight, maxWidth)
        }
        return BitmapFactory.decodeFile(file.absolutePath, options)
    }

    private fun sampleSize(width: Int, height: Int, maxWidth: Int): Int {
        var sample = 1
        var w = width
        while (w / sample > maxWidth) {
            sample *= 2
            w = width / sample
        }
        return sample
    }
}
