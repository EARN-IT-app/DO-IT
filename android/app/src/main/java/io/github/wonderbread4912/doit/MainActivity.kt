package io.github.wonderbread4912.doit

import android.Manifest
import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Color
import android.graphics.Typeface
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.view.Gravity
import android.view.View
import android.widget.Button
import android.widget.CheckBox
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView

/** Setup screen: turn on the two permissions, then pick the apps to block. */
class MainActivity : Activity() {
    private lateinit var store: Store
    private lateinit var usageButton: Button
    private lateinit var overlayButton: Button
    private lateinit var statusText: TextView
    private lateinit var appList: LinearLayout

    private val ink = Color.parseColor("#141A2E")
    private val muted = Color.parseColor("#5A6280")
    private val accent = Color.parseColor("#2346E0")
    private val good = Color.parseColor("#1D8A4E")

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        store = Store(this)

        val pad = dp(20)
        val page = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(pad, dp(32), pad, dp(40))
            setBackgroundColor(Color.parseColor("#EEF1F8"))
        }
        page.addView(text("DO IT", 56f, ink, bold = true))
        page.addView(text("Pick the apps that waste your time. When you open one, DO IT stops you until you go outside, take a photo of the sky, and watch the video.", 16f, muted))

        page.addView(heading("1. Let DO IT see which app is open"))
        usageButton = button { startActivity(Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS)) }
        page.addView(usageButton)
        page.addView(text("Find DO IT in the list, tap it, and turn it on. Then come back here.", 14f, muted))

        page.addView(heading("2. Let DO IT appear over other apps"))
        overlayButton = button {
            startActivity(Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION, Uri.parse("package:$packageName")))
        }
        page.addView(overlayButton)
        page.addView(text("Turn on \"Allow display over other apps\", then come back here.", 14f, muted))

        page.addView(heading("3. Pick the apps to block"))
        statusText = text("", 15f, ink, bold = true)
        page.addView(statusText)
        appList = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL }
        page.addView(appList)
        fillAppList()

        setContentView(ScrollView(this).apply { addView(page) })

        if (Build.VERSION.SDK_INT >= 33 &&
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED
        ) {
            requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 1)
        }
    }

    override fun onResume() {
        super.onResume()
        refresh()
    }

    private fun refresh() {
        val usage = hasUsageAccess(this)
        val overlay = canShowOverApps(this)
        usageButton.text = if (usage) "✓ Done" else "Turn on Usage access"
        usageButton.isEnabled = !usage
        overlayButton.text = if (overlay) "✓ Done" else "Turn on Display over other apps"
        overlayButton.isEnabled = !overlay

        val count = store.blocked.size
        statusText.text = when {
            !usage || !overlay -> "Finish steps 1 and 2 so DO IT can block apps."
            count == 0 -> "Tick the apps you want to block."
            else -> "DO IT is on and blocking $count app${if (count == 1) "" else "s"}."
        }
        statusText.setTextColor(if (usage && overlay && count > 0) good else ink)

        if (usage && overlay && count > 0) BlockerService.start(this)
    }

    private fun fillAppList() {
        val pm = packageManager
        val launcher = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)
        val apps = pm.queryIntentActivities(launcher, 0)
            .filter { it.activityInfo.packageName != packageName }
            .distinctBy { it.activityInfo.packageName }
            .sortedBy { it.loadLabel(pm).toString().lowercase() }

        for (info in apps) {
            val pkg = info.activityInfo.packageName
            val row = LinearLayout(this).apply {
                orientation = LinearLayout.HORIZONTAL
                gravity = Gravity.CENTER_VERTICAL
                setPadding(0, dp(6), 0, dp(6))
            }
            row.addView(ImageView(this).apply {
                setImageDrawable(info.loadIcon(pm))
                layoutParams = LinearLayout.LayoutParams(dp(36), dp(36)).apply { marginEnd = dp(12) }
            })
            val box = CheckBox(this).apply {
                text = info.loadLabel(pm)
                textSize = 17f
                setTextColor(ink)
                isChecked = pkg in store.blocked
                layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
                setOnCheckedChangeListener { _, on ->
                    store.blocked = if (on) store.blocked + pkg else store.blocked - pkg
                    refresh()
                }
            }
            row.addView(box)
            row.setOnClickListener { box.toggle() }
            appList.addView(row)
        }
    }

    private fun heading(label: String) = text(label, 19f, ink, bold = true).apply { setPadding(0, dp(28), 0, dp(8)) }

    private fun text(label: String, size: Float, color: Int, bold: Boolean = false) = TextView(this).apply {
        text = label
        textSize = size
        setTextColor(color)
        if (bold) typeface = Typeface.DEFAULT_BOLD
        setPadding(0, dp(4), 0, dp(4))
    }

    private fun button(onTap: (View) -> Unit) = Button(this).apply {
        textSize = 17f
        isAllCaps = false
        typeface = Typeface.DEFAULT_BOLD
        setTextColor(Color.WHITE)
        setBackgroundColor(accent)
        minHeight = dp(56)
        setOnClickListener(onTap)
    }

    private fun dp(v: Int) = (v * resources.displayMetrics.density).toInt()
}
