package com.workspace.worknote

import android.app.Application
import com.workspace.worknote.data.Store
import com.workspace.worknote.logic.Channels
import com.workspace.worknote.settings.ThemeHelper
import com.workspace.worknote.util.AppCtx

class App : Application() {

    override fun onCreate() {
        super.onCreate()
        AppCtx.init(this)
        Store.init(this)
        Channels.ensure(this)
        ThemeHelper.applyNightMode(this)
    }
}
