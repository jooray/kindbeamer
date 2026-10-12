package dev.stkn.kindbeamer

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.print.PrintAttributes
import android.print.PrinterCapabilitiesInfo
import android.print.PrinterId
import android.print.PrinterInfo
import android.printservice.PrintJob
import android.printservice.PrintService
import android.printservice.PrinterDiscoverySession
import android.util.Log
import java.io.File
import java.io.FileInputStream

/**
 * One printer, "KindBeamer". Anything printed to it — a browser page with the
 * reader's own logins, a document from any app — arrives here as the PDF the
 * printing app rendered, and is left in `cache/printed/` for MainActivity to
 * queue like a shared file.
 *
 * The service cannot open the app itself: by the time a job is queued the
 * print dialog has closed, and Android blocks activity starts from the
 * background (logged as "Background activity launch blocked"). So it posts a
 * notification that opens the app, and the file also waits for the next time
 * the app comes to the front, notifications or not.
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
        val file = try {
            save(printJob)
        } catch (e: Exception) {
            Log.w(TAG, "could not read the print job", e)
            printJob.fail(e.message ?: "could not read the document")
            return
        }
        printJob.complete()
        notifyReady(file.nameWithoutExtension)
    }

    private fun notifyReady(title: String) {
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
        val open = PendingIntent.getActivity(
            this,
            0,
            Intent(this, MainActivity::class.java)
                .setAction(MainActivity.ACTION_PRINTED)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP),
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
            .setContentTitle(getString(R.string.print_ready_title))
            .setContentText(title)
            .setContentIntent(open)
            .setAutoCancel(true)
            .build()
        // Without the permission this is dropped quietly; the file still waits.
        try {
            manager.notify(NOTIFICATION_ID, notification)
        } catch (e: SecurityException) {
            Log.i(TAG, "no notification permission; the PDF waits for the app", e)
        }
    }

    override fun onRequestCancelPrintJob(printJob: PrintJob) {
        printJob.cancel()
    }

    /**
     * The spooled PDF, copied to the cache under the job's name (a browser
     * names it after the page title), which the app offers as the title.
     */
    private fun save(printJob: PrintJob): File {
        val dir = File(cacheDir, "printed").apply { mkdirs() }
        // Older jobs are sent or abandoned by now.
        listOf(dir, File(dir, MainActivity.TAKEN_DIR)).forEach { d ->
            d.listFiles()?.filter { it.isFile && System.currentTimeMillis() - it.lastModified() > DAY_MS }
                ?.forEach { it.delete() }
        }
        val name = fileName(printJob.info.label)
        var file = File(dir, "$name.pdf")
        var n = 2
        while (file.exists() || File(File(dir, MainActivity.TAKEN_DIR), file.name).exists()) {
            file = File(dir, "$name ($n).pdf").also { n++ }
        }
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
        const val NOTIFICATION_ID = 1
        private const val DAY_MS = 24 * 60 * 60 * 1000L

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
