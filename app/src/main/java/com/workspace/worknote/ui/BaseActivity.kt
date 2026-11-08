package com.workspace.worknote.ui

import android.content.Context
import androidx.appcompat.app.AppCompatActivity
import com.workspace.worknote.settings.ThemeHelper

/** 所有界面都从这里继承：统一处理字号缩放与界面语言 */
open class BaseActivity : AppCompatActivity() {

    override fun attachBaseContext(newBase: Context) {
        super.attachBaseContext(ThemeHelper.wrap(newBase))
    }
}
