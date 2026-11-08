package com.workspace.worknote.logic

import android.content.Context
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.media.Ringtone
import android.media.RingtoneManager
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import com.workspace.worknote.settings.AppSettings
import com.workspace.worknote.settings.RingtoneStore

/**
 * 提醒弹出时的响铃 / 震动，开关在「我 → 通知」里。
 * 铃声可以是系统默认提醒音，也可以是用户自己选的一首歌（存在应用私有目录里的副本）。
 * 通知渠道本身被设成「静音」，出声统一由这里负责，避免系统音和自定义音一起响。
 */
object Alerts {

    private var ringtone: Ringtone? = null
    private var player: MediaPlayer? = null

    fun fire(context: Context) {
        if (AppSettings.notifySound(context)) playSound(context)
        if (AppSettings.notifyVibrate(context)) vibrate(context)
    }

    private fun playSound(context: Context) {
        runCatching {
            stop()
            val custom = RingtoneStore.current(context)
            if (custom != null) {
                playCustom(context, custom)
            } else {
                playDefault(context)
            }
        }
    }

    private fun playCustom(context: Context, file: java.io.File) {
        val mp = MediaPlayer()
        mp.setAudioAttributes(
            AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_NOTIFICATION)
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .build()
        )
        mp.setDataSource(file.absolutePath)
        mp.isLooping = false
        mp.prepare()
        mp.start()
        player = mp
    }

    private fun playDefault(context: Context) {
        val uri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
        val r = RingtoneManager.getRingtone(context.applicationContext, uri)
        r?.play()
        ringtone = r
    }

    private fun vibrate(context: Context) {
        runCatching {
            val vibrator: Vibrator? = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                val manager = context.getSystemService(VibratorManager::class.java)
                manager?.defaultVibrator
            } else {
                @Suppress("DEPRECATION")
                context.getSystemService(Vibrator::class.java)
            }
            if (vibrator == null || !vibrator.hasVibrator()) return
            val pattern = longArrayOf(0, 220, 120, 220, 120, 400)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                vibrator.vibrate(VibrationEffect.createWaveform(pattern, -1))
            } else {
                @Suppress("DEPRECATION")
                vibrator.vibrate(pattern, -1)
            }
        }
    }

    fun stop() {
        runCatching { ringtone?.stop() }
        ringtone = null
        runCatching {
            player?.let { mp ->
                if (mp.isPlaying) mp.stop()
                mp.release()
            }
        }
        player = null
    }
}
