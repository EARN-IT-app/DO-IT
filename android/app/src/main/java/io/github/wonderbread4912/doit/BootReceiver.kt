package io.github.wonderbread4912.doit

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/** Turns DO IT back on after the phone restarts. */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED && Store(context).blocked.isNotEmpty()) {
            BlockerService.start(context)
        }
    }
}
