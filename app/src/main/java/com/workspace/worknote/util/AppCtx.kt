package com.workspace.worknote.util

import android.content.Context

/** 保存 Application Context，给没有 Context 的工具类取字符串资源用 */
object AppCtx {
    lateinit var context: Context
        private set

    fun init(context: Context) {
        this.context = context.applicationContext
    }
}
