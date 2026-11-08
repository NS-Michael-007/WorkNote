package com.workspace.worknote.logic

import android.content.Context
import android.content.Intent

/** 数据变动后通知界面刷新 */
object UiBus {

    const val ACTION_REFRESH = "com.workspace.worknote.ACTION_REFRESH"

    fun notify(context: Context) {
        context.sendBroadcast(Intent(ACTION_REFRESH).setPackage(context.packageName))
    }
}
