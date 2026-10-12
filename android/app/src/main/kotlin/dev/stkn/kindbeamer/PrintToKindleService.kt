package dev.stkn.kindbeamer

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.print.PrintAttributes
import android.print.PrinterCapabilitiesInfo
import android.print.PrinterId
import android.print.PrinterInfo
import android.printservice.PrintJob
import android.printservice.PrintService
import android.printservice.PrinterDiscoverySession
import android.util.Log
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject
import java.io.File
import java.io.FileInputStream

/**
 * One printer, "KindBeamer". Anything printed to it — a browser page with the
 * reader's own logins, a document from any app — arrives here as the PDF the
 * printing app rendered. What happens next is the "Send printed pages right
 * away" setting (`print_auto_send` in settings.json):
 *
 * - **Off** (default): the PDF is left in `cache/printed/` for MainActivity to
 *   queue like a shared file. The service cannot open the app itself — by the
 *   time a job is queued the print dialog has closed, and Android blocks
 *   activity starts from the background ("Background activity launch
 *   blocked") — so a notification does, and the file also waits for the next
 *   time the app comes to the front.
 * - **On**: a headless Flutter engine runs `printSendMain` (lib/main.dart),
 *   which sends the PDF the way `--send` does: the stored sign-in, the devices
 *   ticked last, the library copy and the PDF layout. The job stays
 *   "printing" meanwhile, so the system's own print notification shows the
 *   send under way. A notification says where it went; a failed send leaves
 *   the PDF queued for the window and says why.
 *
 * Paper is Kindle-shaped (3:4), 6 × 8 in by default, the size the app
 * typesets Markdown at, so the PDF reads on a 6" screen as it is. Letter and
 * A4 are left out on purpose: the print dialog keeps the previous printer's
 * paper when the new printer offers it too, which would bring them back as
 * the default.
 */
class PrintToKindleService : PrintService() {

    override fun onCreatePrinterDiscoverySession(): PrinterDiscoverySession = Session()

    private inner class Session : PrinterDiscoverySession() {
        override fun onStartPrinterDiscovery(priorityList: MutableList<PrinterId>) {
            addPrinters(listOf(printer()))
        }

        override fun onStopPrinterDiscovery() {}
        override fun onValidatePrinters(printerIds: MutableList<PrinterId>) {}
        override fun onStartPrinterStateTracking(printerId: PrinterId) {
            addPrinters(listOf(printer()))
        }

        override fun onStopPrinterStateTracking(printerId: PrinterId) {}
        override fun onDestroy() {}
    }

    private fun printer(): PrinterInfo {
        val id = generatePrinterId(PRINTER_ID)
        val caps = PrinterCapabilitiesInfo.Builder(id)
            .addMediaSize(KINDLE_PAGE, true)
            .addMediaSize(SCRIBE_PAGE, false)
            .addMediaSize(PrintAttributes.MediaSize.ISO_A5, false)
            .addResolution(PrintAttributes.Resolution("300dpi", "300 dpi", 300, 300), true)
            .setColorModes(
                PrintAttributes.COLOR_MODE_COLOR or PrintAttributes.COLOR_MODE_MONOCHROME,
                PrintAttributes.COLOR_MODE_COLOR,
            )
            .setMinMargins(PrintAttributes.Margins.NO_MARGINS)
            .build()
        return PrinterInfo.Builder(id, getString(R.string.print_printer_name), PrinterInfo.STATUS_IDLE)
            .setDescription(getString(R.string.print_printer_description))
            .setCapabilities(caps)
            .build()
    }

    override fun onPrintJobQueued(printJob: PrintJob) {
        if (!printJob.isQueued) return
        printJob.start()
        val queue = File(cacheDir, "printed")
        val autoSend = autoSendOn()
        val file = try {
            save(printJob, if (autoSend) File(queue, SENDING_DIR) else queue)
        } catch (e: Exception) {
            Log.w(TAG, "could not read the print job", e)
            printJob.fail(e.message ?: "could not read the document")
            return
        }
        if (!autoSend) {
            printJob.complete()
            notifyReady(file.nameWithoutExtension)
            return
        }
        sendInBackground(file) { ok, message ->
            if (ok) {
                file.delete()
                notify(getString(R.string.print_sent_title), message, open = false)
            } else {
                // Not lost: it waits in the window's queue, with the reason.
                file.renameTo(File(queue, file.name))
                notify(getString(R.string.print_not_sent_title), message, open = true)
            }
            if (!printJob.isCompleted && !printJob.isFailed && !printJob.isCancelled) printJob.complete()
        }
    }

    override fun onRequestCancelPrintJob(printJob: PrintJob) {
        printJob.cancel()
    }

    private fun autoSendOn(): Boolean = try {
        JSONObject(File(filesDir, "settings.json").readText()).optBoolean("print_auto_send", false)
    } catch (_: Exception) {
        false
    }

    /**
     * Runs `printSendMain` in an engine of its own and reports whether the
     * send went through, with the sentence to show. The engine is torn down as
     * soon as it answers, or after [SEND_TIMEOUT_MS].
     */
    private fun sendInBackground(file: File, done: (ok: Boolean, message: String) -> Unit) {
        val main = Handler(Looper.getMainLooper())
        val loader = FlutterInjector.instance().flutterLoader()
        loader.startInitialization(applicationContext)
        loader.ensureInitializationCompleteAsync(applicationContext, null, main) {
            val engine = FlutterEngine(applicationContext)
            var finished = false
            fun finish(ok: Boolean, message: String) {
                if (finished) return
                finished = true
                main.removeCallbacksAndMessages(null)
                // Not from inside the engine's own call.
                main.post { engine.destroy() }
                done(ok, message)
            }
            MethodChannel(engine.dartExecutor.binaryMessenger, PRINT_CHANNEL).setMethodCallHandler { call, result ->
                when (call.method) {
                    "job" -> result.success(mapOf("path" to file.absolutePath))
                    "done" -> {
                        result.success(null)
                        val ok = call.argument<Boolean>("ok") == true
                        val message = call.argument<String>("message").orEmpty()
                        finish(ok, message.ifEmpty { file.nameWithoutExtension })
                    }
                    else -> result.notImplemented()
                }
            }
            main.postDelayed(
                { finish(false, getString(R.string.print_send_timeout)) },
                SEND_TIMEOUT_MS,
            )
            engine.dartExecutor.executeDartEntrypoint(
                DartExecutor.DartEntrypoint(loader.findAppBundlePath(), "printSendMain"),
            )
        }
    }

    private fun notifyReady(title: String) {
        notify(getString(R.string.print_ready_title), title, open = true, id = READY_NOTIFICATION_ID)
    }

    /** Dropped quietly without the notification permission; the file still waits. */
    private fun notify(title: String, text: String, open: Boolean, id: Int = nextId()) {
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            manager.createNotificationChannel(
                NotificationChannel(
                    CHANNEL_ID,
                    getString(R.string.print_channel_name),
                    NotificationManager.IMPORTANCE_HIGH,
                ),
            )
        }
        val intent = Intent(this, MainActivity::class.java)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        if (open) intent.action = MainActivity.ACTION_PRINTED
        val tap = PendingIntent.getActivity(
            this,
            id,
            intent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }
        val notification = builder
            .setSmallIcon(R.drawable.ic_stat_kindbeamer)
            .setContentTitle(title)
            .setContentText(text)
            .setStyle(Notification.BigTextStyle().bigText(text))
            .setContentIntent(tap)
            .setAutoCancel(true)
            .build()
        try {
            manager.notify(id, notification)
        } catch (e: SecurityException) {
            Log.i(TAG, "no notification permission", e)
        }
    }

    /**
     * The spooled PDF, copied under the job's name (a browser names it after
     * the page title), which the app offers as the title.
     */
    private fun save(printJob: PrintJob, dir: File): File {
        dir.mkdirs()
        val root = File(cacheDir, "printed")
        // Older jobs are sent or abandoned by now.
        listOf(root, File(root, MainActivity.TAKEN_DIR), File(root, SENDING_DIR)).forEach { d ->
            d.listFiles()?.filter { it.isFile && System.currentTimeMillis() - it.lastModified() > DAY_MS }
                ?.forEach { it.delete() }
        }
        val name = fileName(printJob.info.label)
        fun taken(f: File) = listOf(root, File(root, MainActivity.TAKEN_DIR), File(root, SENDING_DIR))
            .any { File(it, f.name).exists() }
        var file = File(dir, "$name.pdf")
        var n = 2
        while (taken(file)) file = File(dir, "$name ($n).pdf").also { n++ }
        // Written aside and renamed, so the app never takes a half-written file.
        val part = File(dir, "${file.name}.part")
        val data = printJob.document.data ?: error("the print job carried no document")
        data.use { pfd ->
            FileInputStream(pfd.fileDescriptor).use { input ->
                part.outputStream().use { input.copyTo(it) }
            }
        }
        if (!part.renameTo(file)) error("could not store the document")
        return file
    }

    companion object {
        private const val TAG = "KindBeamerPrint"
        private const val PRINTER_ID = "kindbeamer"
        private const val CHANNEL_ID = "printed"
        private const val PRINT_CHANNEL = "dev.stkn.kindbeamer/print"
        private const val SENDING_DIR = "sending"
        private const val DAY_MS = 24 * 60 * 60 * 1000L
        private const val SEND_TIMEOUT_MS = 5 * 60 * 1000L
        const val READY_NOTIFICATION_ID = 1
        private var lastId = 100

        private fun nextId() = ++lastId

        val KINDLE_PAGE = PrintAttributes.MediaSize("KINDLE_6X8", "Kindle page (6 × 8 in)", 6000, 8000)
        val SCRIBE_PAGE = PrintAttributes.MediaSize("KINDLE_SCRIBE", "Kindle Scribe page (7.5 × 10 in)", 7500, 10000)

        fun fileName(label: String?): String {
            val clean = (label ?: "")
                .removeSuffix(".pdf")
                .replace(Regex("[\\\\/:*?\"<>|\\u0000-\\u001f]+"), " ")
                .replace(Regex("\\s+"), " ")
                .trim()
                .take(120)
            return clean.ifEmpty { "Printed page" }
        }
    }
}
