package io.github.wonderbread4912.doit

import android.app.Activity
import android.os.Bundle
import android.widget.Toast

/** Opened by doit://break?minutes=N from the website once you finish the steps. */
class BreakLinkActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val asked = intent?.data?.getQueryParameter("minutes")?.toIntOrNull() ?: 10
        val minutes = asked.coerceIn(1, MAX_BREAK_MINUTES)
        Store(this).breakUntil = System.currentTimeMillis() + minutes * 60_000L
        Toast.makeText(this, "Break started: $minutes minutes. Enjoy it.", Toast.LENGTH_LONG).show()
        finish()
    }
}
