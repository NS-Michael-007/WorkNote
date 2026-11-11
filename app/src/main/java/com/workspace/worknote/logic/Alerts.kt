package com.workspace.worknote.logic

import android.content.Context
import android.media.AudioAttributes
import android.media.AudioDeviceInfo
import android.media.AudioManager
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
 *
 * 蓝牙耳机连着的时候，铃声改走媒体流：声音进耳机，手机扬声器不再外放；
 * 没连耳机时仍旧走通知流（该响就响）。
 */
object Alerts {

    private var ringtone: Ringtone? = null
    private var player: MediaPlayer? = null

    fun fire(context: Context) {
        if (AppSettings.notifySound(context)) playSound(context)
        if (AppSettings.notifyVibrate(context)) vibrate(context)
    }

    /**
     * 当前是否有蓝牙耳机 / 音箱在当输出设备。
     * 用 AudioManager 查实际输出设备，比只看蓝牙开关状态更准：连着但没在输出时不算。
     */
    private fun bluetoothOutputConnected(context: Context): Boolean {
        val manager = context.getSystemService(AudioManager::class.java) ?: return false
        val outputs = manager.getDevices(AudioManager.GET_DEVICES_OUTPUTS)
        return outputs.any { device ->
            when (device.type) {
                AudioDeviceInfo.TYPE_BLUETOOTH_A2DP,
                AudioDeviceInfo.TYPE_BLUETOOTH_SCO -> true
                else -> Build.VERSION.SDK_INT >= Build.VERSION_CODES.S &&
                    device.type == AudioDeviceInfo.TYPE_BLE_HEADSET
            }
        }
    }

    private fun attrsFor(bluetooth: Boolean): AudioAttributes =
        if (bluetooth) {
            // 媒体流：连着蓝牙时会被路由到耳机，手机端不出声
            AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_MEDIA)
                .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                .build()
        } else {
            AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_NOTIFICATION)
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .build()
        }

    private fun playSound(context: Context) {
        runCatching {
            stop()
            val bluetooth = bluetoothOutputConnected(context)
            val custom = RingtoneStore.current(context)
            if (custom != null) {
                playCustom(context, custom, bluetooth)
            } else {
                playDefault(context, bluetooth)
            }
        }
    }

    private fun playCustom(context: Context, file: java.io.File, bluetooth: Boolean) {
        val mp = MediaPlayer()
        mp.setAudioAttributes(attrsFor(bluetooth))
        mp.setDataSource(file.absolutePath)
        mp.isLooping = false
        mp.prepare()
        mp.start()
        player = mp
    }

    private fun playDefault(context: Context, bluetooth: Boolean) {
        val uri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
        val r = RingtoneManager.getRingtone(context.applicationContext, uri)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            runCatching { r?.setAudioAttributes(attrsFor(bluetooth)) }
        }
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
