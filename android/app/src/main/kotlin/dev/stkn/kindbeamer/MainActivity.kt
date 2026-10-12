package dev.stkn.kindbeamer

import android.Manifest
import android.app.NotificationManager
import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * PDFs from the KindBeamer printer go through the same channel the macOS
 * build uses: native only queues and nudges, and Dart drains the queue with
 * `takePendingFiles` at startup, on `filesAvailable` and on resume
 * (SPECIFICATION.md §6). The queue is the print service's directory rather
 * than memory, so a PDF printed while the app was not running is still there
 * when it opens. Shares and "Open with" keep going through
 * receive_sharing_intent.
 */
class MainActivity : FlutterActivity() {
    private var channel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "takePendingFiles" -> result.success(takePrinted())
                    "openPrintSettings" -> {
                        openPrintSettings()
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        if (intent.action == ACTION_PRINTED) channel?.invokeMethod("filesAvailable", null)
    }

    /**
     * Printed PDFs not yet queued, oldest first, moved aside so each is taken
     * once; they stay on disk while they sit in the queue.
     */
    private fun takePrinted(): List<String> {
        val dir = File(cacheDir, "printed")
        val taken = File(dir, TAKEN_DIR).apply { mkdirs() }
        val files = dir.listFiles { f -> f.isFile && f.name.endsWith(".pdf") }
            ?.sortedBy { it.lastModified() }
            .orEmpty()
        if (files.isNotEmpty()) {
            (getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager)
                .cancel(PrintToKindleService.NOTIFICATION_ID)
        }
        return files.mapNotNull { f ->
            val dest = File(taken, f.name)
            if (f.renameTo(dest)) dest.absolutePath else null
        }
    }

    /**
     * The printer has to be switched on in the system's print settings. The
     * notification that brings a printed PDF here needs permission on Android
     * 13+, and this is the moment the user is setting printing up, so ask
     * first and open the settings once they have answered.
     */
    private fun openPrintSettings() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED
        ) {
            requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), REQUEST_NOTIFICATIONS)
            return
        }
        launchPrintSettings()
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == REQUEST_NOTIFICATIONS) launchPrintSettings()
    }

    private fun launchPrintSettings() {
        try {
            startActivity(Intent(Settings.ACTION_PRINT_SETTINGS))
        } catch (_: ActivityNotFoundException) {
        }
    }

    companion object {
        const val CHANNEL = "dev.stkn.kindbeamer/intake"
        const val ACTION_PRINTED = "dev.stkn.kindbeamer.PRINTED"
        const val TAKEN_DIR = "taken"
        private const val REQUEST_NOTIFICATIONS = 4711
    }
}
