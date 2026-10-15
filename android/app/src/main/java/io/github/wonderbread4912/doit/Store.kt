package io.github.wonderbread4912.doit

import android.app.AppOpsManager
import android.content.Context
import android.os.Process
import android.provider.Settings

const val SITE_URL = "https://wonderbread4912.github.io/DO-IT/?from=android"
const val MAX_BREAK_MINUTES = 60

/** The apps to block and the current break, saved on the phone. */
class Store(context: Context) {
    private val prefs = context.getSharedPreferences("doit", Context.MODE_PRIVATE)

    var blocked: Set<String>
        get() = prefs.getStringSet("blocked", emptySet()) ?: emptySet()
        set(value) = prefs.edit().putStringSet("blocked", value).apply()

    var breakUntil: Long
        get() = prefs.getLong("breakUntil", 0L)
        set(value) = prefs.edit().putLong("breakUntil", value).apply()

    val onBreak: Boolean get() = breakUntil > System.currentTimeMillis()
}

fun hasUsageAccess(context: Context): Boolean {
    val ops = context.getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
    @Suppress("DEPRECATION")
    val mode = ops.checkOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS, Process.myUid(), context.packageName)
    return mode == AppOpsManager.MODE_ALLOWED
}

fun canShowOverApps(context: Context): Boolean = Settings.canDrawOverlays(context)
