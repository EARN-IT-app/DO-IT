package io.github.wonderbread4912.doit

import android.app.Activity
import android.content.Intent
import android.graphics.Color
import android.graphics.Typeface
import android.net.Uri
import android.os.Bundle
import android.view.Gravity
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView

/** The full-screen "STOP." page shown on top of a blocked app. */
class StopActivity : Activity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val pad = dp(28)
        val layout = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER_VERTICAL
            setPadding(pad, pad, pad, pad)
            setBackgroundColor(Color.parseColor("#000000"))
        }
        layout.addView(TextView(this).apply {
            text = "STOP."
            textSize = 72f
            typeface = Typeface.DEFAULT_BOLD
            setTextColor(Color.WHITE)
        })
        layout.addView(TextView(this).apply {
            text = "Get up, go outside, take a photo of the sky, and watch the video. Then you get your break."
            textSize = 18f
            setTextColor(Color.parseColor("#B8B8B8"))
            setPadding(0, dp(12), 0, dp(32))
        })
        layout.addView(bigButton("DO IT", "#00D26A", "#000000") {
            startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(SITE_URL)).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
            finish()
        })
        layout.addView(bigButton("Go to my home screen", "#2E2E2E", "#FFFFFF") { goHome() })
        setContentView(layout)
    }

    override fun onResume() {
        super.onResume()
        showing = true
    }

    override fun onPause() {
        super.onPause()
        showing = false
    }

    // Back never returns to the blocked app.
    @Deprecated("Deprecated in Java")
    override fun onBackPressed() = goHome()

    private fun goHome() {
        startActivity(Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
        finish()
    }

    private fun bigButton(label: String, bg: String, fg: String, onTap: () -> Unit) = Button(this).apply {
        text = label
        textSize = 20f
        isAllCaps = false
        typeface = Typeface.DEFAULT_BOLD
        setTextColor(Color.parseColor(fg))
        setBackgroundColor(Color.parseColor(bg))
        minHeight = dp(64)
        layoutParams = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT)
            .apply { topMargin = dp(12) }
        setOnClickListener { onTap() }
    }

    private fun dp(v: Int) = (v * resources.displayMetrics.density).toInt()

    companion object {
        @Volatile var showing = false
    }
}
